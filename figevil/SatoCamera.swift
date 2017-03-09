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
    /** has to be 0 < gifFPS <= 15 and 30 */
    var gifFPS: Int
    var liveGifDuration: Int
    
    /** "Play Speed" */
    var gifPlayDuration: TimeInterval {
        return TimeInterval(liveGifDuration)
    }
    var frameCaptureFrequency: Int {
        return Int(sampleBufferFPS) / gifFPS
    }
    var sampleBufferFPS: Int32 = 30
    var liveGifFrameTotalCount: Int {
        return liveGifDuration * gifFPS
    }
    
    /** The amount of time each frame stays. */
    var frameDelay: Double {
        return Double(liveGifDuration) / Double(liveGifFrameTotalCount)
    }
    
    init(gifFPS: Int, liveGifDuration: Int) {
        self.gifFPS = gifFPS
        self.liveGifDuration = liveGifDuration
    }
}

protocol SatoCameraOutput {
    /** Show the filtered output image view. */
    var outputImageView: UIImageView? { get set }
    
    /** Show the live preview. GLKView is added to this view. */
    var sampleBufferView: UIView? { get }
    
    var cameraAccessAuthorizationStatus: Bool { get set }
}

// gifFPS 3: CPU 70-80%, memory 61MB
// gifFPS 10: 70-80%, 150MB , connection sometimes lost when snapped. if succeeded, memory is 280MB
// gifFPS 10 with resizing simultaneausly: 70-80%, +300MB, crash after memory usage reached 300MB. Memory keeps growing because second half of resizing method is not executed in background.
// gifFPS 10: resizing in main thread, +105%, 50MB, lags, UI not responding

// source CIImage = width: 1920, height: 1080
// videoGLKPreviewViewBounds = width: 1334, height: 749
// imageDrawRect = width: 1920, height: 1078


var currentLiveGifPreset: LiveGifPreset = LiveGifPreset(gifFPS: 5, liveGifDuration: 3)

/** Init with frame and set yourself (client) to cameraOutput delegate and call start(). */
class SatoCamera: NSObject {
    
    /** view where CIImage created from sample buffer in didOutputSampleBuffer() is shown. Updated real time. */
    fileprivate var videoGLKPreview: GLKView?
    fileprivate var videoDevice: AVCaptureDevice?
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    /** needed for real time image processing. instantiated with EAGLContext. */
    fileprivate var ciContext: CIContext?
    fileprivate var eaglContext: EAGLContext?
    /** stores GLKView's drawableWidth (The width, in pixels, of the underlying framebuffer object.) */
    fileprivate var videoGLKPreviewViewBounds: CGRect?
    fileprivate var captureSession: AVCaptureSession?
    fileprivate var photoOutput: AVCapturePhotoOutput?
    
    /** array of unfiltered CIImage from didOutputSampleBuffer.
     Filter should be applied when stop recording gif but not real time
     because that slows down preview. */
    fileprivate var unfilteredCIImages: [CIImage] = [CIImage]()
    
    /** count variable to count how many times the method gets called */
    fileprivate var didOutputSampleBufferMethodCallCount: Int = 0
    /** video frame will be captured once in the frequency how many times didOutputSample buffer is called. */
    
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
    
    /** Can be set after initialization. videoGLKPreview will be added subview to sampleBufferOutput in dataSource. */
    var cameraOutput: SatoCameraOutput? {
        didSet {
            
            guard let videoGLKPreview = videoGLKPreview, let cameraOutput = cameraOutput else {
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
            
            sampleBufferOutput.addSubview(videoGLKPreview)
        }
    }
    
    /** Store filter name. Changed by a client through change(filterName:). */
    private var filterName: String = "CISepiaTone"
    
    /** Holds the current filter. */
    var currentFilter: Filter = Filter.list()[0]
    
    init(frame: CGRect) {
        self.frame = frame
        //http://stackoverflow.com/questions/29619846/in-swift-didset-doesn-t-fire-when-invoked-from-init
        super.init()
        
        // EAGLContext object manages an OpenGL ES rendering context
        eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2)
        guard let eaglContext = eaglContext else {
            print("eaglContext is nil")
            return
        }
        // Configure GLK preview view.
        // GLKView is A default implementation for views that draw their content using OpenGL ES.
        videoGLKPreview = GLKView(frame: frame, context: eaglContext)
        guard let videoGLKPreview = videoGLKPreview else {
            print("videoGLKPreviewView is nil")
            return
        }
        
        videoGLKPreview.enableSetNeedsDisplay = false
        
        // the original video image from the back SatoCamera is landscape. apply 90 degree transform
        videoGLKPreview.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
        
        // Always set frame after transformation
        videoGLKPreview.frame = frame
        
        videoGLKPreview.bindDrawable()
        videoGLKPreviewViewBounds = CGRect.zero
        // drawable width The width, in pixels, of the underlying framebuffer object.
        videoGLKPreviewViewBounds?.size.width = CGFloat(videoGLKPreview.drawableWidth) // 1334 pixels
        videoGLKPreviewViewBounds?.size.height = CGFloat(videoGLKPreview.drawableHeight) // 749 pixels
        
        ciContext = CIContext(eaglContext: eaglContext)
        setupOpenGL()
        
        _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(printPerSecond), userInfo: nil, repeats: true)
        //initialStart()
    }

    func setupOpenGL() {
        // OpenGL official documentation: https://www.khronos.org/registry/OpenGL-Refpages/es2.0/
        // clear eagl view to grey
        glClearColor(0.5, 0.5, 0.5, 1.0) // specify clear values for the color buffers
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT)) // clear buffers to preset values
        // set the blend mode to "source over" so that CI will use that
        glEnable(GLenum(GL_BLEND)) // glEnable — enable or disable server-side GL capabilities
        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA)) // specify pixel arithmetics
    }
    
    var time = 0
    var didOutputSampleBufferCountPerSecond = 0
    func printPerSecond() {
        time += 1
        didOutputSampleBufferCountPerSecond = 0
        //print("\(time) second passed -------------------------------------------------------------------------------------")
    }
    
    /** Start running capture session. */
    internal func initialStart() {
        
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
        }
        
        guard let captureSession = captureSession else {
            print("capture session is nil")
            return
        }
        
        captureSession.sessionPreset = preset
        
        // Configure video output setting
        let outputSettings: [AnyHashable : Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = outputSettings
        
        // Ensure frames are delivered to the delegate in order
        // http://stackoverflow.com/questions/31775356/modifying-uiview-above-glkview-causing-crashes
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
        
        if videoDevice.hasTorch && videoDevice.isTorchAvailable {
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = torchState
                videoDevice.unlockForConfiguration()
            } catch {
                
            }
        }
        
        // Add output object to session
        captureSession.addOutput(videoDataOutput)
        captureSession.addOutput(photoOutput)
        
        // Assemble all the settings together
        captureSession.commitConfiguration()
        captureSession.startRunning()
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
            // this changes the AVCaptureSessionPreset to AVCaptureSessionPresetInputPriority 
            // which specifies that the capture session does not control audio and video output settings.
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
        let touchPoint = touch.location(in: videoGLKPreview)
        
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
        //startRecordingGif()
    }
    
    /** */
    internal func stop() {
        cameraOutput?.sampleBufferView?.isHidden = true
        captureSession?.stopRunning()
    }
    
    /** Set to the initial state. */
    internal func reset() {
        unfilteredCIImages.removeAll()
        cameraOutput?.sampleBufferView?.isHidden = false
        didOutputSampleBufferMethodCallCount = 0
        resultImageView = nil
        gif = nil
        
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
    internal func save(drawImage: UIImage?, textImage: UIImage?, completion: ((_ saved: Bool, _ fileSize: String?) -> ())?) {
        
        guard let gif = gif else {
            print("gif is nil in \(#function)")
            return
        }
        
        gif.save(drawImage: drawImage, textImage: textImage, completion: completion)
    }

    /** Toggles back camera or front camera. */
    internal func toggleCamera() {
        let cameraDevice = getCameraDevice()
        guard let captureSession = captureSession else {
            print("capture session is nil in \(#function)")
            return
        }
        
        didOutputSampleBufferMethodCallCount = 0
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
    
    /** Indicates if SatoCamera is recording gif.*/
    fileprivate var isRecording: Bool = false
    
    /** Starts recording gif.*/
    internal func startRecordingGif() {
        isRecording = true
    }
    
    /** Stops recording gif. */
    internal func stopRecordingGif() {
        stop()
        isRecording = false
        showGif()
    }
    
    var isGifSnapped: Bool = false
    
    /** Snaps live gif. Starts image post-storing. */
    internal func snapLiveGif() {
        isGifSnapped = true
    }
    
    /** Stops image post-storing. Calls showGif to show gif.*/
    fileprivate func stopLiveGif() {
        isGifSnapped = false
        stop()
        showGif()
    }
    
    /** Creates an image view with images for animation. Show the image view on output image view. */
    func showGif() {
        let gif = Gif(originalCIImages: unfilteredCIImages,
                      currentGifFPS: currentLiveGifPreset.gifFPS,
                      newGifFPS: currentLiveGifPreset.gifFPS,
                      gifPlayDuration: currentLiveGifPreset.gifPlayDuration,
                      scale: 0,
                      frame: frame,
                      filter: currentFilter,
                      frameDelay: currentLiveGifPreset.frameDelay)
        
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
}

extension SatoCamera: FilterImageEffectDelegate {
    
    /** Changes the current filter. If camera is live, applies filter to the live preview. 
     If a gif or image has already been taken and is showing on outputImageView, applies fitler to it. */
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?) {
        // set filtered output image to outputImageView
        guard let captureSession = captureSession else {
            print("capture session is nil in \(#function)")
            return
        }
        
        // if camera is running, just change the filter name
        guard let filter = filter else {
            print("filter is nil in \(#function)")
            return
        }
        
        self.currentFilter = filter
        
        // if camera is not running
        if !captureSession.isRunning {
            showGif()
        }
    }
}

var imageDrawRect: CGRect!

extension SatoCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /** Calculate ciimage's extent to be fit to GKLView. */
    func calculateDrawRect(sourceImage: CIImage) -> CGRect {
//        // sourceExtent = width: 1920, height: 1080
//        let sourceExtent: CGRect = sourceImage.extent
//        let sourceAspect = sourceExtent.width / sourceExtent.height
//        
//        guard let videoGLKPreviewViewBounds = videoGLKPreviewViewBounds else {
//            print("videoGLKPreviewViewBounds is nil")
//            return frame
//        }
//        
//        // we want to maintain the aspect radio of the screen size, so we clip the video image
//        let previewAspect = videoGLKPreviewViewBounds.width / videoGLKPreviewViewBounds.height
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
//        return drawRect
        return sourceImage.extent
    }
    
    /** Called the specified times (FPS) every second. Converts sample buffer into CIImage. 
     Applies filter to it. Draw the CIImage into CIContext to update GLKView.
     In background, store CIImages into array one by one. Resizing should be done in background.*/
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        didOutputSampleBufferCountPerSecond += 1
        
        // Store in background thread
        DispatchQueue.global(qos: .background).async {
            self.didOutputSampleBufferMethodCallCount += 1
            if self.didOutputSampleBufferMethodCallCount % currentLiveGifPreset.frameCaptureFrequency == 0 {
                // get deep copied CIImage from sample buffer so that the ciimage has no reference to sample buffer anymore
                if let deepCopiedCIImage = sampleBuffer.ciImage {
                    if self.isRecording {
                        self.unfilteredCIImages.append(deepCopiedCIImage)
                    } else {
                        // detect snap user action
                        if !self.isGifSnapped {
                            self.unfilteredCIImages.append(deepCopiedCIImage)
                            
                            if self.unfilteredCIImages.count == currentLiveGifPreset.liveGifFrameTotalCount / 2 {
                                self.unfilteredCIImages.remove(at: 0)
                            }
                        } else {
                            // if snapped, start post-storing
                            self.unfilteredCIImages.append(deepCopiedCIImage)
                            if self.unfilteredCIImages.count == currentLiveGifPreset.liveGifFrameTotalCount {
                                DispatchQueue.main.async {
                                    // UI change has to be in main thread
                                    self.stopLiveGif()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("image buffer is nil")
            return
        }
        let sourceImage: CIImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // filteredImage has the same address as sourceImage
        guard let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: sourceImage) else {
            print("filtered image is nil in \(#function)")
            return
        }
        
        // execute the first time this method gets called.
        if didOutputSampleBufferMethodCallCount == 0 {
            imageDrawRect = calculateDrawRect(sourceImage: sourceImage)
        }

        videoGLKPreview?.bindDrawable()
        
        // Prepare CIContext with EAGLContext
        if eaglContext != EAGLContext.current() {
            EAGLContext.setCurrent(eaglContext)
        }

        ciContext?.draw(filteredImage, in: videoGLKPreviewViewBounds!, from: imageDrawRect)
        videoGLKPreview?.display()        
    }
}

extension CIImage {

    /** Resize CIImage using CIContext. Worst performance according to NSHipster. http://nshipster.com/image-resizing/. */
    func resize(frame: CGRect) -> CIImage? {
        print("BEFORE scaled CIImage extent: \(self.extent) in \(#function)")

        let scale = frame.width / self.extent.width
        
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        //let rectFrame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        //let vectorFrame = CIVector(cgRect: frame)
        //filter.setValue(vectorFrame, forKey: kCIInputExtentKey) // CILanczosScaleTransform doesn't accept vector frame
        filter.setValue(self, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        guard let outputImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else {
            print("output image is nil in \(#function)")
            return nil
        }
        
        let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
        
        guard let scaledCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            print("scaled CGImage is nil in \(#function)")
            return nil
        }
        
        // code below is not being executed. Execution stops the line above.
        let scaledCIImage = CIImage(cgImage: scaledCGImage)
        print("AFTER scaled CIImage extent: \(scaledCIImage.extent) in \(#function)")
        
        return scaledCIImage
    }
    
    /** Resize CIImage using CGContext. if CIImage is created from sample buffer, CGImage is nil. */
    func resizeWithCGContext(frame: CGRect) -> CIImage? {
        // https://developer.apple.com/reference/coreimage/ciimage/1687603-cgimage
        // If CIImage is created from init(cgImage:) or init(contentsOf:) initializer, cgImage property is value
        // otherwise nil. In that case, to create CGImage from CIImage, use CIContext createCGImage(_:from:)

        // CGImage is nil
        guard let cgImage = self.cgImage else {
            print("CGImage from CIImage is nil")
            return nil
        }
        
        let width = cgImage.width / 2
        let height = cgImage.height / 2
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace
        let bitmapInfo = cgImage.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) else {
            print("context is nil in \(#function)")
            return nil
        }
        
        context.interpolationQuality = CGInterpolationQuality.high
        
        context.draw(cgImage, in:  CGRect(origin: CGPoint.zero, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
        guard let scaledCGImage = context.makeImage() else {
            print("newCGImage is nil in \(#function)")
            return nil
        }
        
        let scaledCIImage = CIImage(cgImage: scaledCGImage)
        return scaledCIImage
    }
}

// https://gist.github.com/valkjsaaa/f9edfc25b4fd592caf82834fafc07759
extension CVPixelBuffer {
    /** Make a deep copy of CVPixelBuffer. */
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
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        }
        return pixelBufferCopyOptional
    }
}

extension CMSampleBuffer {
    /** Make a brand new CIImage from CMSampleBuffer using bitmap. */
    var ciImage: CIImage? {
        get {
            // Get a CMSampleBuffer's Core Video image buffer for the media data
            guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(self) else {
                print("image buffer is nil")
                return nil
            }
    
            // Lock the base address of the pixel buffer
            CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
    
            // Get the number of bytes per row for the pixel buffer
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
            // Get the pixel buffer width and height
            
            let width = CVPixelBufferGetWidth(imageBuffer) // 1920
            let height = CVPixelBufferGetHeight(imageBuffer) // 1080
            
            // Create a device-dependent RGB color space
            let colorSpace = CGColorSpaceCreateDeviceRGB();
    
            // Create a bitmap graphics context with the sample buffer data
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little)
            guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
                print("Error creating context from cvpixelbuffer")
                return nil
            }
            
            // Create a Quartz image from the pixel data in the bitmap graphics context
            guard let quartzImage = context.makeImage() else {
                print("Error creating source image from quatz image")
                return nil
            }
    
            // Unlock the pixel buffer
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

            let sourceImage = CIImage(cgImage: quartzImage)
            
            // resize
            //let scale = UIScreen.main.bounds.width / sourceImage.extent.width
            //sourceImage = sourceImage.applying(CGAffineTransform(scaleX: scale, y: scale)) // 251MB after snapping
            return sourceImage
        }
    }
}
