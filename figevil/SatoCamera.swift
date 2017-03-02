//
//  Camera.swift
//  RealTimeFilteringSwift
//
//  Created by Satoru Sasozaki on 2/16/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit // OpenGL

// For saving gif to camera roll
import ImageIO
import MobileCoreServices
import Photos

// TODO: check camera device is available

/** Indicate camera state. */
enum CameraState {
    case Back
    case Front
}

struct LiveGifPreset {
    var frameCaptureFrequency: Int
    var gifPlayDuration: Double
    var sampleBufferFPS: Int32
    var numOfFramesForGif: Int
    var gifFPS: Int
}

protocol SatoCameraOutput {
    // set outputImageView with filtered image in
    // didFinishProcessingPhotoSampleBuffer when snapping
    // didSetFilter when post changing
    /** Show the filtered output image view. */
    var outputImageView: UIImageView? { get set}
    // set is needed because rotating UIView needs UIImageView. UIImage rotating won't work
    
    /** Show the live preview. GLKView is added to this view. */
    var sampleBufferView: UIView? { get }
}

/** Client of this class has to do
 1. Initialize with frame the client will use for preview
 2. Set delegate to self
 3. Implement delegate methods
 4. Call start() to start running camera
 5. Call capturePhoto() to take a photo. Receive the result image view in receive(filteredImageView:unfilteredImageView:)
 6. Call startRecordingGif() and endRecordingGif(completion:) to record gif
 */
class SatoCamera: NSObject {
    
    /** view where CIImage created from sample buffer in didOutputSampleBuffer() is shown. Updated real time. */
    fileprivate var videoPreview: GLKView?
    fileprivate var videoDevice: AVCaptureDevice?
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    /** needed for real time image processing. instantiated with EAGLContext. */
    fileprivate var ciContext: CIContext?
    fileprivate var eaglContext: EAGLContext?
    fileprivate var videoPreviewViewBounds: CGRect?
    fileprivate var captureSession: AVCaptureSession?
    fileprivate var photoOutput: AVCapturePhotoOutput?
    
    fileprivate static let resizingImageScale: CGFloat = 0.3
    
    /** array of unfiltered CIImage from didOutputSampleBuffer.
     Filter should be applied when stop recording gif but not real time
     because that slows down preview. */
    fileprivate var unfilteredCIImages: [CIImage] = [CIImage]()
    /** Check if gif is generated. */
    fileprivate var isGif: Bool = false
    
    fileprivate var unfilteredCIImage: CIImage?
    
    /** count variable to count how many times the method gets called */
    fileprivate var didOutputSampleBufferMethodCallCount: Int = 0
    /** video frame will be captured once in the frequency how many times didOutputSample buffer is called. */
    
    /** Indicates if SatoCamera is recording gif.*/
    fileprivate var isRecording: Bool = false
    
    /** Frame of preview view in a client. Should be set when being initialized. */
    fileprivate var frame: CGRect
    
    /** Indicates current flash state. Default is off. (off, on, auto) */
    internal var flashState: AVCaptureFlashMode = AVCaptureFlashMode.off
    /** Indicates current torch state. Default is off. (off, on, auto) */
    internal var torchState: AVCaptureTorchMode = AVCaptureTorchMode.off
    
    fileprivate var flashOptions: [AVCaptureFlashMode] = [AVCaptureFlashMode.off, AVCaptureFlashMode.on, AVCaptureFlashMode.auto]
    fileprivate var torchOptions: [AVCaptureTorchMode] = [AVCaptureTorchMode.off, AVCaptureTorchMode.on, AVCaptureTorchMode.auto]
    
    fileprivate var flashOptionIndex: Index = Index(numOfElement: 3)
    fileprivate var torchOptionIndex: Index = Index(numOfElement: 3)
    
    fileprivate var resultImageView: UIImageView?
    
    /** Store the result gif object. */
    var gif: Gif?
    
    /** Indicates the current camera state. */
    var cameraState: CameraState = .Back
    
    /** Can be set after initialization. videoPreview will be added subview to sampleBufferOutput in dataSource. */
    var cameraOutput: SatoCameraOutput? {
        didSet {
            
            guard let videoPreview = videoPreview, let cameraOutput = cameraOutput else {
                print("video preview or camera output is nil")
                return
            }
            
            guard let sampleBufferOutput = cameraOutput.sampleBufferView else {
                print("sample buffer view is nil")
                return
            }
            
            for subview in sampleBufferOutput.subviews {
                subview.removeFromSuperview()
            }
            
            sampleBufferOutput.addSubview(videoPreview)
            print("video preview is set to sample buffer output as a subview")
            
        }
    }
    
    /** Store filter name. Changed by a client through change(filterName:). */
    private var filterName: String = "CISepiaTone"
    
    /** Holds the current filter. */
    var currentFilter: Filter = Filter.list()[0]
    
//    var currentliveGifPreset: LiveGifPreset = LiveGifPreset(frameCaptureFrequency: 2, gifPlayDuration: 1, sampleBufferFrameRate: 30, numOfFramesForGif: 10)
    var currentLiveGifPreset: LiveGifPreset = LiveGifPreset(frameCaptureFrequency: 3, gifPlayDuration: 1, sampleBufferFPS: 30, numOfFramesForGif: 30, gifFPS: 30/3/3)
    
    convenience init(frame: CGRect) {
        self.init(frame: frame, cameraOutput: nil)
    }
    
    init(frame: CGRect, cameraOutput: SatoCameraOutput?) {
        self.frame = frame
        //http://stackoverflow.com/questions/29619846/in-swift-didset-doesn-t-fire-when-invoked-from-init
        // didSet in cameraOutput is not called here before super.init() is called
        self.cameraOutput = cameraOutput
        
        super.init()
        
        // EAGLContext object manages an OpenGL ES rendering context
        eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2)
        guard let eaglContext = eaglContext else {
            print("eaglContext is nil")
            return
        }
        
        // Configure GLK preview view.
        // GLKView is A default implementation for views that draw their content using OpenGL ES.
        videoPreview = GLKView(frame: frame, context: eaglContext)
        guard let videoPreview = videoPreview else {
            print("videoPreviewView is nil")
            return
        }
        
        videoPreview.enableSetNeedsDisplay = false
        
        // the original video image from the back SatoCamera is landscape. apply 90 degree transform
        videoPreview.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
        
        // Always set frame after transformation
        videoPreview.frame = frame
        
        videoPreview.bindDrawable()
        videoPreviewViewBounds = CGRect.zero
        videoPreviewViewBounds?.size.width = CGFloat(videoPreview.drawableWidth)
        videoPreviewViewBounds?.size.height = CGFloat(videoPreview.drawableHeight)
        
        ciContext = CIContext(eaglContext: eaglContext)
        
        cameraOutput?.sampleBufferView?.addSubview(videoPreview)
        
        
        
        _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(printPerSecond), userInfo: nil, repeats: true)
        initialStart()
    }
    var time = 0
    var didOutputSampleBufferCountPerSecond = 0
    func printPerSecond() {
        time += 1
        didOutputSampleBufferCountPerSecond = 0
        //print("\(time) second passed -------------------------------------------------------------------------------------")
    }
    
    /** Start running capture session. */
    private func initialStart() {
        
        // Get video device
        guard let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else {
            print("video device is nil")
            return
        }
        
        self.videoDevice = videoDevice
        
        // If the video device support high preset, set the preset to capture session
        let preset = AVCaptureSessionPresetHigh
        if videoDevice.supportsAVCaptureSessionPreset(preset) {
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = preset
        }
        
        guard let captureSession = captureSession else {
            print("capture session is nil")
            return
        }
        
        // Configure video output setting
        let outputSettings: [AnyHashable : Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = outputSettings
        
        // Ensure frames are delivered to the delegate in order
        let captureSessionQueue = DispatchQueue.main
        // Set delegate to self for didOutputSampleBuffer
        videoDataOutput.setSampleBufferDelegate(self, queue: captureSessionQueue)
        
        // Discard late video frames not to cause lag and be slow
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // add still image output
        photoOutput = AVCapturePhotoOutput()
        
        // Configure input object with device
        // THIS CODE HAS TO BE BEFORE THE FRAME RATE  CONFIG
        // http://stackoverflow.com/questions/20330174/avcapture-capturing-and-getting-framebuffer-at-60-fps-in-ios-7
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            // Add it to session
            captureSession.addInput(videoDeviceInput)
        } catch {
            print("Failed to instantiate input object")
        }
        
        // Minimize visibility or inconsistency of state
        captureSession.beginConfiguration()
        
        if !captureSession.canAddOutput(videoDataOutput) {
            print("cannot add video data output")
            return
        }
        
        setupFrameRate(videoDevice: videoDevice)
        
        // Add output object to session
        captureSession.addOutput(videoDataOutput)
        captureSession.addOutput(photoOutput)
        
        // Assemble all the settings together
        captureSession.commitConfiguration()
        captureSession.startRunning()
        startRecordingGif()
    }
    
    /** Setup frame rate for video device. captureSession.addInput must be called before this method is called. */
    func setupFrameRate(videoDevice: AVCaptureDevice) {
        do {
            try videoDevice.lockForConfiguration()
            // Get the best format available for the video device
            // http://stackoverflow.com/questions/20330174/avcapture-capturing-and-getting-framebuffer-at-60-fps-in-ios-7
            var bestFormat = AVCaptureDeviceFormat()
            for any in videoDevice.formats {
                let format = any as! AVCaptureDeviceFormat
                let frameRateRange = format.videoSupportedFrameRateRanges[0] as! AVFrameRateRange
                
                // get the format with max frame rate of 60
                // DO NOT SET 30. IT WON'T WORK
                if frameRateRange.maxFrameRate == 60 {
                    bestFormat = format
                }
            }
            
            // set the format to the device
            videoDevice.activeFormat = bestFormat
            
            // supported frame rate range is now set to 3 - 60 per second. The default is 3 - 30 per second
            let frameRateRange = videoDevice.activeFormat.videoSupportedFrameRateRanges[0] as? AVFrameRateRange
            
            // max frame duration is the max time duration that takes frame to generate.
            // in the case of 60 fps format, value is 1 and timescale is 3 where frame is generated every 1/3 second.
            let _ = frameRateRange!.maxFrameDuration
            
            // min frame duration is the min time duration that takes frame to genrate.
            // in the case of 60 fps format, value is 1 and timescale is 60 where frame is generated every 1/60 second (theoretically).
            // IMPORTANT: even if you set the best format with over 60 fps, the actual max frame you can get per second
            // is around 40 fps. This is regardless of frame resolution (either AVCaptureSessionPresetLow or High)
            let _ = frameRateRange!.minFrameDuration
            
            // frame is generated every 1/12 second which means didOutputSampleBuffer gets called every 1/12 second
            //let customFrameDuration = CMTime(value: 1, timescale: currentliveGifPreset.frameRate)
            let customFrameDuration = CMTime(value: 1, timescale: currentLiveGifPreset.sampleBufferFPS)
            videoDevice.activeVideoMinFrameDuration = customFrameDuration
            videoDevice.activeVideoMaxFrameDuration = customFrameDuration
            videoDevice.unlockForConfiguration()
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    /** Focus on where it's tapped. */
    internal func tapToFocusAndExposure(touch: UITouch) {
        // http://stackoverflow.com/questions/15838443/iphone-camera-show-focus-rectangle
        let touchPoint = touch.location(in: videoPreview)
        
        print("tap to focus: (x: \(String(format: "%.0f", touchPoint.x)), y: \(String(format: "%.0f", touchPoint.y))) in \(self)")
        let adjustedCoordinatePoint = CGPoint(x: frame.width - touchPoint.y, y: touchPoint.x)
        print("adjusted point: (x: \(String(format: "%.0f", adjustedCoordinatePoint.x)) y: \(String(format: "%.0f", adjustedCoordinatePoint.y)))")
        
        guard let videoDevice = videoDevice else {
            print("video device is nil")
            return
        }
        
        let adjustedPoint = CGPoint(x: adjustedCoordinatePoint.x / frame.width, y: adjustedCoordinatePoint.y / frame.height)
        
        if videoDevice.isFocusPointOfInterestSupported && videoDevice.isFocusModeSupported(AVCaptureFocusMode.autoFocus) && videoDevice.isExposureModeSupported(AVCaptureExposureMode.autoExpose) {
            do {
                // lock device to change
                try videoDevice.lockForConfiguration()
                // https://developer.apple.com/reference/avfoundation/avcapturedevice/1385853-focuspointofinterest
                
                // set point
                videoDevice.focusPointOfInterest = adjustedPoint
                videoDevice.exposurePointOfInterest = adjustedPoint
                
                // execute operation now
                videoDevice.focusMode = AVCaptureFocusMode.autoFocus
                videoDevice.exposureMode = AVCaptureExposureMode.continuousAutoExposure
                
                videoDevice.unlockForConfiguration()
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        
        // feedback rect view
        let feedbackView = UIView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 50, height: 50)))
        feedbackView.center = adjustedCoordinatePoint
        feedbackView.layer.borderColor = UIColor.white.cgColor
        feedbackView.layer.borderWidth = 2.0
        feedbackView.backgroundColor = UIColor.clear
        cameraOutput?.sampleBufferView?.addSubview(feedbackView)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            // Put your code which should be executed with a delay here
            feedbackView.removeFromSuperview()
        })
    }
    
    internal func toggleFlash() -> String {
        let flashMode = flashOptions[flashOptionIndex.increment()]
        let torchMode = torchOptions[torchOptionIndex.increment()]
        
        guard let videoDevice = videoDevice else {
            print("video device or photo settings is nil")
            return "Error happened in \(#function): video device or photo settings is nil"
        }
        
        if videoDevice.hasFlash && videoDevice.isFlashAvailable && videoDevice.hasTorch && videoDevice.isTorchAvailable {
            do {
                try videoDevice.lockForConfiguration()
                flashState = flashMode
                torchState = torchMode
                videoDevice.unlockForConfiguration()
            } catch {
                
            }
        }
        var returnText = ""
        switch flashState {
        case AVCaptureFlashMode.off:
            returnText = "Off"
        case AVCaptureFlashMode.on:
            returnText = "On"
        case AVCaptureFlashMode.auto:
            returnText = "Auto"
        }
        
        return returnText
    }
    
    internal func toggleTorch() -> String {
        let torchMode = torchOptions[torchOptionIndex.increment()]
        
        guard let videoDevice = videoDevice else {
            print("video device or photo settings is nil")
            return "Error happened in \(#function): video device or photo settings is nil"
        }
        
        if videoDevice.hasTorch && videoDevice.isTorchAvailable {
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = torchMode
                torchState = torchMode
                videoDevice.unlockForConfiguration()
            } catch {
                
            }
        }
        
        var returnText = ""
        switch torchState {
        case AVCaptureTorchMode.off:
            returnText = "Off"
        case AVCaptureTorchMode.on:
            returnText = "On"
        case AVCaptureTorchMode.auto:
            returnText = "Auto"
        }
        
        return returnText
    }
    
    /** Resumes camera. */
    internal func start() {
        captureSession?.startRunning()
        startRecordingGif()
    }
    
    internal func stop() {
        cameraOutput?.sampleBufferView?.isHidden = true
        captureSession?.stopRunning()
    }
    
    /** Set to the initial state. */
    internal func reset() {
        unfilteredCIImages.removeAll()
        unfilteredCIImage = nil
        cameraOutput?.sampleBufferView?.isHidden = false
        isGif = false
        didOutputSampleBufferMethodCallCount = 0
        
        if let cameraOutput = cameraOutput {
            if let outputImageView = cameraOutput.outputImageView {
                outputImageView.isHidden = false
                for subview in outputImageView.subviews {
                    subview.removeFromSuperview()
                }
            }
        }
        start()
    }
    
    
    /** Saves output image to camera roll. */
    internal func save(drawImage: UIImage?, textImage: UIImage?, completion: ((Bool) -> ())?) {
        
        guard let gif = gif else {
            print("gif is nil in \(#function)")
            return
        }
        
        gif.save(drawImage: drawImage, textImage: textImage, completion: completion)
    }
//
//    /** Renders drawings and texts into image. Needs to be saved to disk by save(). */
//    internal func renderStillImage(drawImage: UIImage?, textImage: UIImage?) -> UIImage? {
//        let resultImage: UIImage?
//        UIGraphicsBeginImageContext(frame.size)
//        resultImageView?.image?.draw(in: frame)
//        drawImage?.draw(in: frame)
//        textImage?.draw(in: frame)
//        if let renderedImage = UIGraphicsGetImageFromCurrentImageContext() {
//            resultImage = renderedImage
//        } else {
//            resultImage = nil
//        }
//        UIGraphicsEndImageContext()
//        return resultImage
//    }
    
    /** Toggles back camera or front camera. */
    internal func toggleCamera() {
        let cameraDevice = getCameraDevice()
        guard let captureSession = captureSession else {
            print("capture session is nil in \(#function)")
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(videoDeviceInput)
        videoDevice = cameraDevice
        
        // Configure input object with device
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            // Add it to session
            if let videoDeviceInput = videoDeviceInput {
                captureSession.addInput(videoDeviceInput)
            } else {
                print("videoDeviceInput is nil")
            }
            
        } catch {
            print("Failed to instantiate input object")
        }
        captureSession.commitConfiguration()
    }
    
    /** Get camera device based on cameraState. */
    private func getCameraDevice() -> AVCaptureDevice {
        var cameraDevice: AVCaptureDevice
        switch cameraState {
        case .Back:
            cameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.front)
            cameraState = .Front
        case .Front:
            cameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.back)
            cameraState = .Back
        }
        return cameraDevice
    }
    
    /** Store CIImage captured in didOutputSampleBuffer into array */
    fileprivate func store(image: CIImage, to images: inout [CIImage]) {
        images.append(image)
    }
    
    internal func startRecordingGif() {
        
        // set torch
        if let videoDevice = videoDevice {
            if videoDevice.hasTorch && videoDevice.isTorchAvailable {
                do {
                    try videoDevice.lockForConfiguration()
                    videoDevice.torchMode = torchState
                    videoDevice.unlockForConfiguration()
                } catch {
                    
                }
            }
        }
        //isRecording = true
        isGif = true
    }
    
    var isGifSnapped: Bool = false
    internal func snapGif() {
        isGifSnapped = true
    }
    
    internal func stopRecordingGif() {
        isGifSnapped = false
        // Set torch
        if let videoDevice = videoDevice {
            if videoDevice.hasTorch && videoDevice.isTorchAvailable {
                do {
                    try videoDevice.lockForConfiguration()
                    videoDevice.torchMode = AVCaptureTorchMode.off
                    videoDevice.unlockForConfiguration()
                } catch {
                    
                }
            }
        }
        
        stop()
        
        //let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: <#T##CIImage#>)
        
        guard let filteredCIImages = currentFilter.generateFilteredCIImages(sourceImages: unfilteredCIImages) else {
            print("filtered CIImages are nil in \(#function)")
            return
        }
        
        let gif = Gif(originalCIImages: filteredCIImages, currentGifFPS: currentLiveGifPreset.gifFPS, newGifFPS: currentLiveGifPreset.gifFPS, scale: 0, frame: frame)
        guard let gifImageView = gif.gifImageView else {
            print("gif image view is nil")
            return
        }
        self.gif = gif
        
        if let cameraOutput = cameraOutput {
            if let outputImageView = cameraOutput.outputImageView {
                outputImageView.isHidden = false
                for subview in outputImageView.subviews {
                    subview.removeFromSuperview()
                }
            }
        }
        
        cameraOutput?.outputImageView?.addSubview(gifImageView)
        gifImageView.startAnimating()
    }

    
//    internal func stopRecordingGif() {
//        isGifSnapped = false
//        // Set torch
//        if let videoDevice = videoDevice {
//            if videoDevice.hasTorch && videoDevice.isTorchAvailable {
//                do {
//                    try videoDevice.lockForConfiguration()
//                    videoDevice.torchMode = AVCaptureTorchMode.off
//                    videoDevice.unlockForConfiguration()
//                } catch {
//                    
//                }
//            }
//        }
//        
//        stop()
//        
//        guard let orientUIImages = fixOrientationAndApplyFilter(ciImages: unfilteredCIImages) else {
//            print("orient uiimages is nil in \(#function)")
//            return
//        }
//        
//        //        guard let resizedUIImages = resizeUIImages(orientUIImages) else {
//        //            print("resized UIImages is nil")
//        //            return
//        //        }
//        
//        let resizedUIImages = orientUIImages
//        
//        guard let gifImageView = UIImageView.generateGifImageView(with: resizedUIImages, frame: frame, duration: currentLiveGifPreset.gifPlayDuration) else {
//            print("failed to produce gif image")
//            return
//        }
//        
//        if let cameraOutput = cameraOutput {
//            if let outputImageView = cameraOutput.outputImageView {
//                outputImageView.isHidden = false
//                for subview in outputImageView.subviews {
//                    subview.removeFromSuperview()
//                }
//            }
//        }
//        
//        resultImageView = gifImageView
//        cameraOutput?.outputImageView?.addSubview(gifImageView)
//        gifImageView.startAnimating()
//    }
    
//    func resizeCIImage(_ ciImage: CIImage) -> CIImage? {
//        let scale = frame.width / ciImage.extent.width
//        
//        let filter = CIFilter(name: "CILanczosScaleTransform")!
//        //let rectFrame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
//        //let vectorFrame = CIVector(cgRect: frame)
//        //filter.setValue(vectorFrame, forKey: kCIInputExtentKey) // CILanczosScaleTransform doesn't accept vector frame
//        filter.setValue(ciImage, forKey: kCIInputImageKey)
//        filter.setValue(scale, forKey: kCIInputScaleKey)
//        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
//        
//        guard let outputImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else {
//            print("output image is nil in \(#function)")
//            return nil
//        }
//        
//        let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
//        
//        guard let scaledCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
//            print("scaled CGImage is nil in \(#function)")
//            return nil
//        }
//        
//        let scaledCIImage = CIImage(cgImage: scaledCGImage)
//        return scaledCIImage
//    }
//    
//    func resizeUIImages(_ uiImages: [UIImage]) -> [UIImage]? {
//        var newImages = [UIImage]()
//        for image in uiImages {
//            if let newImage = resizeUIImage(image) {
//                newImages.append(newImage)
//            } else {
//                print("resizeWithCGImage(uiImage:) returned nil")
//            }
//        }
//        return newImages
//    }
//    
//    func resizeUIImage(_ uiImage: UIImage) -> UIImage? {
//        if let cgImage = uiImage.cgImage {
//            let width: Int = Int(frame.width) / 2
//            let height: Int = Int(frame.height) / 2
//            let bitsPerComponent = cgImage.bitsPerComponent
//            let bytesPerRow = cgImage.bytesPerRow
//            let colorSpace = cgImage.colorSpace
//            let bitmapInfo = cgImage.bitmapInfo
//            
//            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue)
//            
//            context!.interpolationQuality = CGInterpolationQuality.low //.high
//            
//            context?.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
//            
//            let scaledImage = context!.makeImage().flatMap { UIImage(cgImage: $0) }
//            print("UIImage is resized: \(scaledImage?.size) in \(#function)")
//            return scaledImage
//        }
//        print("cgimage from uiimage is nil in \(#function)")
//        return nil
//    }
}

extension SatoCamera: FilterImageEffectDelegate {
    
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?) {
        // set filtered output image to outputImageView
        guard let captureSession = captureSession else {
            print("capture session is nil in \(#function)")
            return
        }
        
        // if camera is running, just change the filter name
        //self.filterName = filterName
        //self.filterIndex = indexPath.item
        
        guard let filter = filter else {
            print("filter is nil in \(#function)")
            return
        }
        
        self.currentFilter = filter
        
        // if camera is not running
        if !captureSession.isRunning {
            
            if isGif {
                
                guard let filteredUIImages = fixOrientationAndApplyFilter(ciImages: unfilteredCIImages) else {
                    print("filtered uiimages is nil in \(#function)")
                    return
                }
                
                guard let gifImageView = UIImageView.generateGifImageView(with: filteredUIImages, frame: frame, duration: currentLiveGifPreset.gifPlayDuration) else {
                    print("failed to produce gif image")
                    return
                }
                
                if let cameraOutput = cameraOutput {
                    if let outputImageView = cameraOutput.outputImageView {
                        for subview in outputImageView.subviews {
                            subview.removeFromSuperview()
                        }
                    }
                }
                
                cameraOutput?.outputImageView?.addSubview(gifImageView)
                gifImageView.startAnimating()
                
            } else {
                // set outputImageView with filtered image.
                guard let unfilteredCIImage = unfilteredCIImage else {
                    print("unfilteredCIImage is nil in \(#function)")
                    return
                }
                
                guard let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: unfilteredCIImage) else {
                    print("filtered image is nil")
                    return
                }
                
                let rotatedFilteredUIImage = fixOrientation(ciImage: filteredImage)
                
                if let cameraOutput = cameraOutput {
                    if let outputImageView = cameraOutput.outputImageView {
                        for subview in outputImageView.subviews {
                            subview.removeFromSuperview()
                        }
                    }
                }
                
                let filteredUIImageView = UIImageView(image: rotatedFilteredUIImage)
                filteredUIImageView.frame = frame
                cameraOutput?.outputImageView?.addSubview(filteredUIImageView)
            }
        }
    }
}

extension SatoCamera: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    /** Called about every millisecond. Apply filter here and output video frame to preview view.
     If recording is on, store video frame both filtered and unfiltered priodically.
     */
//    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
//        didOutputSampleBufferCountPerSecond += 1
//        //print("\t \(didOutputSampleBufferCountPerSecond)th call of didOutputSampleBuffer()")
//        
//        guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//            print("image buffer is nil")
//            return
//        }
//        
//        let sourceImage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
//        let sourceExtent: CGRect = sourceImage.extent
//        
//        guard let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: sourceImage) else {
//            print("filtered image is nil")
//            return
//        }
//        
//        didOutputSampleBufferMethodCallCount += 1
//        if didOutputSampleBufferMethodCallCount % currentLiveGifPreset.frameCaptureFrequency == 0 {
//            
//            if !isGifSnapped {
//                // gif before snapping
//                //                if let resizedCIImage = resizeCIImage(sourceImage) {
//                //                    store(image: resizedCIImage, to: &unfilteredCIImages)
//                //                    if unfilteredCIImages.count == 6 {
//                //                        unfilteredCIImages.remove(at: 0)
//                //                    }
//                //                } else {
//                //                    print("resized ciimage is nil in \(#function)")
//                //                }
//                
//                store(image: sourceImage, to: &unfilteredCIImages)
//                if unfilteredCIImages.count == currentLiveGifPreset.numOfFramesForGif / 2  {
//                    unfilteredCIImages.remove(at: 0)
//                }
//            } else {
//                //                // gif snapped
//                //                if let resizedCIImage = resizeCIImage(sourceImage) {
//                //                    store(image: resizedCIImage, to: &unfilteredCIImages)
//                //                    if unfilteredCIImages.count == 10 {
//                //                        stopRecordingGif()
//                //                    }
//                //                }
//                store(image: sourceImage, to: &unfilteredCIImages)
//                if unfilteredCIImages.count == currentLiveGifPreset.numOfFramesForGif {
//                    stopRecordingGif()
//                }
//            }
//        }
//        
//        let sourceAspect = sourceExtent.width / sourceExtent.height
//        
//        guard let videoPreviewViewBounds = videoPreviewViewBounds else {
//            print("videoPreviewViewBounds is nil")
//            return
//        }
//        
//        // we want to maintain the aspect radio of the screen size, so we clip the video image
//        let previewAspect = videoPreviewViewBounds.width / videoPreviewViewBounds.height
//        
//        var drawRect: CGRect = sourceExtent
//        
//        if sourceAspect > previewAspect {
//            drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0
//            drawRect.size.width = drawRect.size.height * previewAspect
//        } else {
//            drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0
//            drawRect.size.height = drawRect.size.width / previewAspect
//        }
//        
//        videoPreview?.bindDrawable()
//        
//        // Prepare CIContext with EAGLContext
//        if eaglContext != EAGLContext.current() {
//            EAGLContext.setCurrent(eaglContext)
//        }
//        
//        // OpenGL official documentation: https://www.khronos.org/registry/OpenGL-Refpages/es2.0/
//        // clear eagl view to grey
//        glClearColor(0.5, 0.5, 0.5, 1.0) // specify clear values for the color buffers
//        glClear(GLbitfield(GL_COLOR_BUFFER_BIT)) // clear buffers to preset values
//        // set the blend mode to "source over" so that CI will use that
//        glEnable(GLenum(GL_BLEND)) // glEnable — enable or disable server-side GL capabilities
//        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA)) // specify pixel arithmetic
//        
//        ciContext?.draw(filteredImage, in: videoPreviewViewBounds, from: drawRect)
//        
//        // This causes runtime error with no log sometimes. That's because setNeedsDisplay is being called on a background thread, according to http://stackoverflow.com/questions/31775356/modifying-uiview-above-glkview-causing-crashes
//        /*
//         -display should be called when the view has been set to ignore calls to setNeedsDisplay. This method is used by
//         the GLKViewController to invoke the draw method. It can also be used when not using a GLKViewController and custom
//         control of the display loop is needed.
//         */
//        // http://stackoverflow.com/questions/26082262/exc-bad-access-with-glteximage2d-in-glkviewcontroller
//        // http://qiita.com/shu223/items/2ef1e8901e96c65fd155
//        
//        videoPreview?.display()
//    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        didOutputSampleBufferCountPerSecond += 1
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("image buffer is nil")
            return
        }
        
        guard let copyPixelBuffer = pixelBuffer.deepcopy() else {
            print("copy pixel buffer is nil")
            return
        }
        
        let sourceImage: CIImage = CIImage(cvPixelBuffer: copyPixelBuffer)
        
        guard let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: sourceImage) else {
            print("filtered image is nil in \(#function)")
            return
        }
        
        let sourceExtent: CGRect = sourceImage.extent
        
        didOutputSampleBufferMethodCallCount += 1
        if didOutputSampleBufferMethodCallCount % currentLiveGifPreset.frameCaptureFrequency == 0 {
            if !isGifSnapped {
                store(image: sourceImage, to: &unfilteredCIImages)
                
                if unfilteredCIImages.count == currentLiveGifPreset.numOfFramesForGif / 2 {
                    unfilteredCIImages.remove(at: 0)
                }
            } else {
                store(image: sourceImage, to: &unfilteredCIImages)
                if unfilteredCIImages.count == currentLiveGifPreset.numOfFramesForGif {
                    stopRecordingGif()
                }
            }
        }
        
        let sourceAspect = sourceExtent.width / sourceExtent.height
        
        guard let videoPreviewViewBounds = videoPreviewViewBounds else {
            print("videoPreviewViewBounds is nil")
            return
        }
        
        // we want to maintain the aspect radio of the screen size, so we clip the video image
        let previewAspect = videoPreviewViewBounds.width / videoPreviewViewBounds.height
        
        var drawRect: CGRect = sourceExtent
        
        if sourceAspect > previewAspect {
            drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0
            drawRect.size.width = drawRect.size.height * previewAspect
        } else {
            drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0
            drawRect.size.height = drawRect.size.width / previewAspect
        }
        
        videoPreview?.bindDrawable()
        
        // Prepare CIContext with EAGLContext
        if eaglContext != EAGLContext.current() {
            EAGLContext.setCurrent(eaglContext)
        }
        
        // OpenGL official documentation: https://www.khronos.org/registry/OpenGL-Refpages/es2.0/
        // clear eagl view to grey
        glClearColor(0.5, 0.5, 0.5, 1.0) // specify clear values for the color buffers
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT)) // clear buffers to preset values
        // set the blend mode to "source over" so that CI will use that
        glEnable(GLenum(GL_BLEND)) // glEnable — enable or disable server-side GL capabilities
        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA)) // specify pixel arithmetic
        
        ciContext?.draw(filteredImage, in: videoPreviewViewBounds, from: drawRect)
        
        // This causes runtime error with no log sometimes. That's because setNeedsDisplay is being called on a background thread, according to http://stackoverflow.com/questions/31775356/modifying-uiview-above-glkview-causing-crashes
        /*
         -display should be called when the view has been set to ignore calls to setNeedsDisplay. This method is used by
         the GLKViewController to invoke the draw method. It can also be used when not using a GLKViewController and custom
         control of the display loop is needed.
         */
        // http://stackoverflow.com/questions/26082262/exc-bad-access-with-glteximage2d-in-glkviewcontroller
        // http://qiita.com/shu223/items/2ef1e8901e96c65fd155
        
        
        //print("end of \(#function)")
        videoPreview?.display()
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("sample buffer is dropped")
    }

    
    /** Captures an image. Fires didFinishProcessingPhotoSampleBuffer to get image. */
    internal func capturePhoto() {
        
        // TODO: Research
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160]
        
        settings.previewPhotoFormat = previewFormat
        settings.flashMode = flashState
        
        
        guard let photoOutput = photoOutput else {
            print("photo output or photo setting is nil")
            return
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /** get video frame and convert it to image. */
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let error = error {
            print(error.localizedDescription)
        } else if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            guard let sourceImage = CIImage(data: dataImage) else {
                print("CIImage is nil")
                return
            }
            
            // Save sourceImage to class property for post filter editing
            unfilteredCIImage = sourceImage
            
            guard let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: sourceImage) else {
                print("filtered image is nil")
                return
            }
            
            // set orientation right or left and rotate it by 90 or -90 degrees to fix rotation
            guard let rotatedUIImage = fixOrientation(ciImage: filteredImage) else {
                print("rotatedUIImage is nil in \(#function)")
                return
            }
            
            let filteredImageView = UIImageView(image: rotatedUIImage)
            filteredImageView.frame = frame
            
            resultImageView = filteredImageView
            // client setup
            cameraOutput?.outputImageView?.addSubview(filteredImageView)
            
            stop()
        }
    }
    
    /** Fixes orientation of array of CIImage and apply filters to it.
     Fixing orientation and applying filter have to be done at the same time
     because fixing orientation only produces UIImage with its CIImage property nil.
     */
    func fixOrientationAndApplyFilter(ciImages: [CIImage]) -> [UIImage]? {
        var rotatedUIImages = [UIImage]()
        
        for ciImage in ciImages {
            
            guard let filteredCIImage = currentFilter.generateFilteredCIImage(sourceImage: ciImage) else {
                print("filtered image is nil")
                return nil
            }
            
            let filteredUIImage = UIImage(ciImage: filteredCIImage, scale: 0, orientation: UIImageOrientation.right)
            
            guard let rotatedImage = rotate(image: filteredUIImage) else {
                print("rotatedImage is nil in \(#function)")
                return nil
            }
            rotatedUIImages.append(rotatedImage)
        }
        
        return rotatedUIImages
    }
    
    /** Fixes orientation of CIImage and returns UIImage.
     Set orientation right or left and rotate it by 90 or -90 degrees to fix rotation. */
    func fixOrientation(ciImage: CIImage) -> UIImage? {
        // set orientation right or left and rotate it by 90 or -90 degrees to fix rotation
        let filteredUIImage = UIImage(ciImage: ciImage, scale: 0, orientation: UIImageOrientation.right)
        guard let rotatedImage = rotate(image: filteredUIImage) else {
            print("rotatedImage is nil in \(#function)")
            return nil
        }
        
        return rotatedImage
    }
    
    /** Rotates image by 90 degrees. */
    func rotate(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContext(image.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("context is nil in \(#function)")
            return nil
        }
        image.draw(at: CGPoint.zero)
        context.rotate(by: CGFloat(M_PI_2)) // M_PI_2 = pi / 2 = 90 degrees (pi radians = 180 degrees)
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
}

/** The methods that handle only CIImage are in this extension. */
extension CIImage {
    // Apply filter to array of CIImage
    class func applyFilter(to images: [CIImage], filter: Filter) -> [CIImage] {
        var newImages = [CIImage]()
        
        for image in images {
            
            guard let newImage = filter.generateFilteredCIImage(sourceImage: image) else {
                print("filtered image is nil")
                break
            }
            
            newImages.append(newImage)
        }
        return newImages
    }
}

// https://gist.github.com/valkjsaaa/f9edfc25b4fd592caf82834fafc07759
extension CVPixelBuffer {
    func deepcopy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional:CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, format, nil, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags.readOnly)
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            print("dataSize: \(dataSize)")
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        }
        return pixelBufferCopyOptional
    }
}
