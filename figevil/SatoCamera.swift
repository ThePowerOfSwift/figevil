//
//  Camera.swift
//  RealTimeFilteringSwift
//
//  Created by Satoru Sasozaki on 2/16/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit

import QuartzCore

import MobileCoreServices // for HDD saving
import Photos // for HDD saving

/** Indicate camera state. */
enum CameraFace {
    case Back
    case Front
}

protocol SatoCameraOutput {
    /** Show the filtered output image view. */
    var outputImageView: UIImageView? { get set }
    /** Show the live preview. GLKView is added to this view. */
    var sampleBufferView: UIView? { get }    
}

/** Init with frame and set yourself (client) to cameraOutput delegate and call start(). */
class SatoCamera: NSObject {
    
    // MARK: Basic Configuration for capturing
    fileprivate var videoGLKPreview: GLKView!
    fileprivate var videoDevice: AVCaptureDevice?
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var ciContext: CIContext?
    fileprivate var eaglContext: EAGLContext?
    /** stores GLKView's drawableWidth (The width, in pixels, of the underlying framebuffer object.) */
    fileprivate var videoGLKPreviewViewBounds: CGRect?
    fileprivate var session = AVCaptureSession()
    //internal var sessionQueue: DispatchQueue = DispatchQueue.main
    internal var sessionQueue = DispatchQueue(label: "sessionQueue", attributes: [], target: nil)
    /** Frame of sampleBufferView of CameraOutput delegate. Should be set when being initialized. */
    fileprivate var frame: CGRect
    
    // MARK: State
    fileprivate var cameraFace: CameraFace = .Back
    fileprivate var currentFilter: Filter = Filter.list()[0]
    fileprivate var light = Light()

    // MARK: Results
    /** Stores the result gif object. */
    /** count variable to count how many times the method gets called */
    fileprivate var didOutputSampleBufferMethodCallCount: Int = 0
    
    // MARK: User action state
    /** Indicates if SatoCamera is recording gif.*/
    fileprivate var isRecording: Bool = false
    /** Detect if user click the snap button. */
    var isSnappedGif: Bool = false
    
    // MARK: Delegate
    /** Delegate for SatoCamera. videoGLKPreview will be added subview to sampleBufferOutput in dataSource. */
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
    
    // Gif setting
    var currentLiveGifPreset: LiveGifPreset = LiveGifPreset(gifFPS: 10, liveGifDuration: 3)

    private enum SessionSetupResult {
        case success
        case configurationFailed
        case notAuthorized
    }
    
    private var setupResult: SessionSetupResult = .success
    
    // MARK: HDD saving
    var filteredUIImages = [UIImage]()
    var originalURLs = [URL]()
    var resizedURLs = [URL]()
    let fileManager = FileManager()
    let maxPixelSize = 337 //1334 is original

    func askUserCameraAccessAuthorization(completion: ((_ authorized: Bool)->())?) {
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) != AVAuthorizationStatus.authorized {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                completion?(granted)
            })
        } else {
            completion?(true)
        }
    }
    
    // MARK: - Setups
    init(frame: CGRect) {
        self.frame = frame
        //http://stackoverflow.com/questions/29619846/in-swift-didset-doesn-t-fire-when-invoked-from-init
        super.init()
        
        // EAGLContext object manages an OpenGL ES rendering context
        guard let eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
            print("eaglContext is nil")
            setupResult = .configurationFailed
            return
        }
        self.eaglContext = eaglContext
        
        videoGLKPreview = GLKView(frame: frame, context: eaglContext)
        videoGLKPreview.enableSetNeedsDisplay = false // disable normal UIView drawing cycle

        // the original video image from the back SatoCamera is landscape. apply 90 degree transform
        //videoGLKPreview.transform = backCameraTransform
        // Always set frame after transformation
        videoGLKPreview.frame = frame

        videoGLKPreview.bindDrawable()
        videoGLKPreviewViewBounds = CGRect.zero
        // drawable width The width, in pixels, of the underlying framebuffer object.
        videoGLKPreviewViewBounds?.size.width = CGFloat(videoGLKPreview.drawableWidth) // 1334 pixels
        videoGLKPreviewViewBounds?.size.height = CGFloat(videoGLKPreview.drawableHeight) // 749 pixels
        
        ciContext = CIContext(eaglContext: eaglContext)
        setupOpenGL()
        
        configureSession()
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
    
    /** Start running capture session. */
    internal func configureSession() {
        
        //print("status bar orientation is landscape?: \(UIApplication.shared.statusBarOrientation.isLandscape)")
        // Get video device
        guard let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else {
            print("video device is nil")
            setupResult = .configurationFailed
            return
        }
        
        self.videoDevice = videoDevice
        
        // If the video device support high preset, set the preset to capture session
        if videoDevice.supportsAVCaptureSessionPreset(AVCaptureSessionPresetHigh) {
            session.sessionPreset = AVCaptureSessionPresetHigh
        } else if videoDevice.supportsAVCaptureSessionPreset(AVCaptureSessionPresetMedium) {
            session.sessionPreset = AVCaptureSessionPresetMedium
        } else {
            session.sessionPreset = AVCaptureSessionPresetLow
        }
        

        let videoDataOutput = AVCaptureVideoDataOutput()
        // Configure video output setting
        let outputSettings: [AnyHashable : Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.videoSettings = outputSettings
        // Ensure frames are delivered to the delegate in order
        // http://stackoverflow.com/questions/31775356/modifying-uiview-above-glkview-causing-crashes
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // Configure input object with device
        // THIS CODE HAS TO BE BEFORE THE FRAME RATE  CONFIG
        // http://stackoverflow.com/questions/20330174/avcapture-capturing-and-getting-framebuffer-at-60-fps-in-ios-7
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                print("video device input cannot be added to session.")
                setupResult = .configurationFailed
            }
            
        } catch {
            print("Failed to instantiate input object")
            setupResult = .configurationFailed
        }
        
        // Minimize visibility or inconsistency of state
        session.beginConfiguration()
        
        if videoDevice.hasTorch && videoDevice.isTorchAvailable {
            do {
                try videoDevice.lockForConfiguration()
                //videoDevice.torchMode = torchState
                videoDevice.torchMode = light.torchState
                videoDevice.unlockForConfiguration()
            } catch {
                print("failed to lock device")
                setupResult = .configurationFailed
            }
        }
        
        // Add output object to session
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        } else {
            print("cannot add video data output")
            setupResult = .configurationFailed
        }
        
        //configureOrientation(for: cameraFace)
        if let connection = videoDataOutput.connection(withMediaType: AVMediaTypeVideo) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        
        // Assemble all the settings together
        session.commitConfiguration()
        session.startRunning()
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
        let adjustedCoordinatePoint = CGPoint(x: frame.width - touchPoint.y, y: touchPoint.x)

        guard let videoDevice = videoDevice else {
            print("video device is nil")
            return
        }
        
        // (1 - ) changes the origin to top, right
        // You pass a CGPoint where {0,0} represents the top left of the picture area, and {1,1} represents the bottom right in landscape mode with the home button on the right—this applies even if the device is in portrait mode.
        // https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
        let adjustedPoint = CGPoint(x: 1 - adjustedCoordinatePoint.x / frame.width, y: adjustedCoordinatePoint.y / frame.height)
        
        sessionQueue.async { [unowned self] in
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
                    videoDevice.exposureMode = AVCaptureExposureMode.autoExpose
                    
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
            
            DispatchQueue.main.async {
                self.cameraOutput?.sampleBufferView?.addSubview(feedbackView)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                    // Put your code which should be executed with a delay here
                    feedbackView.removeFromSuperview()
                })
            }
        }
    }
    
    // MARK: - Camera Settings
    internal func toggleFlash() -> String {
        return light.toggleFlash(videoDevice: videoDevice)
    }
    
    internal func toggleTorch() -> String {
        return light.toggleTorch(videoDevice: videoDevice)
    }
    
    /** Toggles back camera or front camera. */
    internal func toggleCamera() {
        let cameraDevice = getCameraDevice()

        didOutputSampleBufferMethodCallCount = 0
        session.beginConfiguration()
        session.removeInput(videoDeviceInput)
        videoDevice = cameraDevice
        
        // Configure input object with device
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            // Add it to session
            if let videoDeviceInput = videoDeviceInput {
                session.addInput(videoDeviceInput)
            } else {
                print("videoDeviceInput is nil")
            }
            
        } catch {
            print("Failed to instantiate input object")
        }
        session.commitConfiguration()
    }
    
    /** Get camera device based on cameraState. */
    private func getCameraDevice() -> AVCaptureDevice {
        var cameraDevice: AVCaptureDevice
        switch cameraFace {
        case .Back:
            cameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.front)
            cameraFace = .Front
        case .Front:
            cameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.back)
            cameraFace = .Back
        }
        return cameraDevice
    }
    
    // MARK: - Camera Controls
    internal func start() {
        session.startRunning()
        if !session.isRunning {
            print("camera failed to run.")
        }
    }
    
    internal func stop() {
        cameraOutput?.sampleBufferView?.isHidden = true
        session.stopRunning()
    }
    
    /** Set to the initial state. */
    internal func reset() {
        originalURLs.removeAll()
        resizedURLs.removeAll()
        renderedURLs.removeAll()
        filteredUIImages.removeAll()
        cameraOutput?.sampleBufferView?.isHidden = false
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
    
    
    // func save cgimage to disk
    // var renderedImage [url]

    var renderedURLs = [URL]()
    internal func render(drawImage: UIImage?, textImage: UIImage?) -> [URL] {
        var urls = [URL]()
        for image in filteredUIImages {
            
            guard let renderedImage = image.render(drawImage: drawImage, textImage: textImage, frame: frame) else {
                print("rendered image is nil in \(#function)")
                break
            }
            
            guard let cgImage = renderedImage.cgImage else {
                print("Could not get cgImage from rendered UIImage in \(#function)")
                break
            }
            
            guard let url = cgImage.saveToDisk(cgImagePropertyOrientation: cgImageOrientation) else {
                print("Could not save cgImage to disk in \(#function)")
                break
            }
            urls.append(url)
        }
        return urls
    }

    internal func save(drawImage: UIImage?, textImage: UIImage?, completion: ((_ saved: Bool, _ fileSize: String?) -> ())?) {
        // render here
        renderedURLs = render(drawImage: drawImage, textImage: textImage)
        if let gifURL = renderedURLs.createGif(frameDelay: 0.5) {
            print(gifURL.filesize!)
            PHPhotoLibrary.requestAuthorization
                { (status) -> Void in
                    switch (status)
                    {
                    case .authorized:
                        // Permission Granted
                        //print("Photo library usage authorized")
                        // save data to the url
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: gifURL)
                        }, completionHandler: { (saved: Bool, error: Error?) in
                            if saved {
                                completion?(true, gifURL.filesize!)
                            } else {
                                print("did not save gif")
                                completion?(false, nil)
                            }
                        })
                    case .denied:
                        // Permission Denied
                        print("User denied")
                    default:
                        print("Restricted")
                    }
            }

        }
    }
    
    // MARK: - Gif Controls
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
    
    /** Snaps live gif. Starts image post-storing. */
    internal func snapLiveGif() {
        isSnappedGif = true
    }
    
    /** Device orientation when image taken. This also set an integer value to be passed with kCGImagePropertyOrientation. */
    var deviceOrientation = UIDeviceOrientation.portrait {
        didSet {
            switch deviceOrientation {
            case .landscapeRight:
                cgImageOrientation = CGImagePropertyOrientation.LandscapeRight
            case .landscapeLeft:
                cgImageOrientation = CGImagePropertyOrientation.LandscapeLeft
            default:
                cgImageOrientation = CGImagePropertyOrientation.Default
            }
        }
    }
    
    /** an integer value to be passed with kCGImagePropertyOrientation. */
    var cgImageOrientation: CGImagePropertyOrientation = CGImagePropertyOrientation.Default
    
    /** Stops image post-storing. Calls showGif to show gif.*/
    fileprivate func stopLiveGif() {
        isSnappedGif = false
        deviceOrientation = UIDevice.current.orientation
        print(deviceOrientation.rawValue)
        stop()
        showGif()
    }
    
    /** Creates an image view with images for animation. Show the image view on output image view. */
    func showGif() {
        
        //if let gifImageView = getGifImageViewFromImageUrls(resizedURLs, filter: currentFilter.filter) {
        
        if let gifImageView = makeGif(from: resizedURLs, filter: currentFilter.filter) {
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
        } else {
            print("gifImageView is nil")
        }
    }

    func makeGif(from urls: [URL], filter: CIFilter?) -> UIImageView? {
        
        filteredUIImages.removeAll()

        for url in urls {
            
            if let image = url.makeUIImage(filter: filter) {
                filteredUIImages.append(image)
            } else {
                print("image is nil in \(#function)")
            }
        }
        
        let imageView = UIImageView(frame: frame)
        imageView.animationImages = filteredUIImages
        imageView.animationRepeatCount = 0
        imageView.animationDuration = 3
        
        return imageView
    }
}

// MARK: - Other Extensions
extension URL {
    var cgImage: CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil) else {
            print("CGImage is nil in \(#function)")
            return nil
        }
        let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        return cgImage
    }
    
    /// Return the filesize of a given URL
    var filesize: String? {
        if let data = NSData(contentsOf: self) {
            let size = Double(data.length)
            let sizeKB = size / 1024.0
            
            return String(format: "%.2fKB", sizeKB)
        } else {
            return nil
        }
    }
    
    /** Resize an image at a given url. */
    func resize(maxSize: Int) -> URL? {
        var sourceOptions: [NSObject: AnyObject] = [kCGImageSourceShouldCache as NSObject: false as AnyObject]
        guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, sourceOptions as CFDictionary?) else {
            print("Error: cannot create image source for resize")
            return nil
        }
        
        sourceOptions[kCGImageSourceCreateThumbnailFromImageAlways as NSObject] = true as AnyObject
        sourceOptions[kCGImageSourceCreateThumbnailWithTransform as NSObject] = true as AnyObject
        sourceOptions[kCGImageSourceThumbnailMaxPixelSize as NSObject] = maxSize as AnyObject
        
        guard let resizedImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, sourceOptions as CFDictionary?) else {
            print("Error: failed to resize image")
            return nil
        }
        
        let path = NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate))
        let outputURL = URL(fileURLWithPath: path)
        
        guard let imageDestination = CGImageDestinationCreateWithURL(outputURL as CFURL, kUTTypeJPEG, 1, nil) else {
            print("Error: cannot create image destination")
            return nil
        }
        
        //        var imageDestinationOptions: [NSObject: AnyObject] = [:]
        //        imageDestinationOptions as CFDictionary?
        CGImageDestinationAddImage(imageDestination, resizedImage, nil)
        
        if !CGImageDestinationFinalize(imageDestination) {
            print("Error: cannot finalize and write image destination for resize")
            return nil
        }
        return outputURL
    }
    
    func makeUIImage(filter: CIFilter?) -> UIImage? {
        guard let cgImage = self.cgImage else {
            print("cgImage is nil in \(#function)")
            return nil
        }
        
        var ciImage = CIImage()
        if let filter = filter {
            ciImage = cgImage.ciImage.applyingFilter(filter.name, withInputParameters: nil)
        } else {
            ciImage = cgImage.ciImage
        }
        
        let context = CIContext(options: nil)
        let filteredCGImage = context.createCGImage(ciImage, from: ciImage.extent)
        
        let uiImage = UIImage(cgImage: filteredCGImage!)
        
        return uiImage
    }
}

extension UIImage {
    func render(drawImage: UIImage?, textImage: UIImage?, frame: CGRect) -> UIImage? {
        UIGraphicsBeginImageContext(frame.size)
        self.draw(in: frame)
        drawImage?.draw(in: frame)
        textImage?.draw(in: frame)
        if let renderedImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            return renderedImage
        }
        
        UIGraphicsEndImageContext()
        return nil
    }
}

// https://developer.apple.com/reference/imageio/kcgimagepropertyorientation
/** Integer value to be passed with kCGImagePropertyOrientation.*/
enum CGImagePropertyOrientation: Int {
    case Default = 1
    /** set Right, Top to CGImage when image taken in landscape right device orientation. */
    case LandscapeRight = 6
    /** set Left, Bottom to CGImage when image taken in landscape left device orientation. */
    case LandscapeLeft = 8
}

extension CGImage {
    var ciImage: CIImage {
        return CIImage(cgImage: self)
    }
    
    func saveToDisk(cgImagePropertyOrientation: CGImagePropertyOrientation) -> URL? {
        let path = NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate))
        let url = URL(fileURLWithPath: path)
        guard let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) else {
            print("Error: cannot create image destination")
            return nil
        }
        
        var imageDestinationOptions: [NSObject: AnyObject] = [:]
        
        // make sure to pass rawValue of CGImagePropertyOrientation but not the object itself
        imageDestinationOptions.updateValue(cgImagePropertyOrientation.rawValue as AnyObject, forKey: kCGImagePropertyOrientation as NSObject)
        
        CGImageDestinationAddImage(imageDestination, self, imageDestinationOptions as CFDictionary?)
        
        if !CGImageDestinationFinalize(imageDestination) {
            print("Error: failed to finalize image destination")
            return nil
        }
        return url
    }
}

extension CMSampleBuffer {
    /** Save image from CVPixelBuffer to disk without loading into memory */
    func saveFrameToDisk(outputURL: URL? = nil) -> URL? {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            print("Error: Image buffer is nil")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Error: cannot retrieve pixel address")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
            return nil
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let data = NSData(bytes: baseAddress, length: rowBytes * height)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        guard let provider = CGDataProvider(data: data) else {
            print("Error: cannot create CGDataProvider")
            return nil
        }
        
        // Assumed
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        
        guard let image = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: rowBytes,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo,
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: CGColorRenderingIntent.defaultIntent) else {
                                    print("Error: cannot create CGImage")
                                    return nil
        }
        
        let path = NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate))
        let url = outputURL ?? URL(fileURLWithPath: path)
        guard let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) else {
            print("Error: cannot create image destination")
            return nil
        }
        
        guard let options = CMCopyDictionaryOfAttachments(nil, self, kCMAttachmentMode_ShouldPropagate) as Dictionary? else {
            print("Error: cannot create options dictionary for image destination")
            return nil
        }
        
        CGImageDestinationAddImage(imageDestination, image, options as CFDictionary?)
        
        if !CGImageDestinationFinalize(imageDestination) {
            print("Error: failed to finalize image destination")
            return nil
        }
        return url
    }
}

extension Sequence where Iterator.Element == URL {
    func createGif(loopCount: Int = 0, frameDelay: Double) -> Iterator.Element? {
        let imageURLs = self as! [URL]
        // Data check
        if imageURLs.count <= 0 {
            return nil
        }
        
        // Generate default output url
        
        let url = userGeneratedGifURL!.appendingPathComponent(String(Date().timeIntervalSinceReferenceDate).appending(".gif"), isDirectory: false)
        
        // Create write-to destination
        guard let gifDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeGIF, imageURLs.count, nil) else {
            print("Error: cannot create image destination is nil")
            return nil
        }
        
        // ImageSource options- do not cache
        let sourceOptions: [NSObject: AnyObject] = [kCGImageSourceShouldCache as NSObject: false as AnyObject]
        
        // Set gif file properties (options)
        var gifDestinationOptions: [NSObject: AnyObject] = [:]
        let gifDictionaryOptions: [NSObject: AnyObject]? = [kCGImagePropertyGIFLoopCount as NSObject: loopCount as AnyObject,
                                                            kCGImagePropertyGIFDelayTime as NSObject: frameDelay as AnyObject]
        gifDestinationOptions[kCGImagePropertyGIFDictionary as NSObject] = gifDictionaryOptions as AnyObject
        CGImageDestinationSetProperties(gifDestination, gifDestinationOptions as CFDictionary?)
        
        // Add images to gif
        for url in imageURLs {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary?) else {
                print("Error: cannot load image source from url \(url)")
                continue
            }
            
            CGImageDestinationAddImageFromSource(gifDestination, imageSource, 0, nil)
        }
        
        // Write gif to disk
        if !CGImageDestinationFinalize(gifDestination) {
            print("Error: cannot finalize gif")
            return nil
        } else {
            print("Saved gif to \(url.path)")
        }
        
        return url
    }
}

// MARK: - FilterImageEffectDelegate
extension SatoCamera: FilterImageEffectDelegate {
    
    /** Changes the current filter. If camera is live, applies filter to the live preview. 
     If a gif or image has already been taken and is showing on outputImageView, applies fitler to it. */
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?) {
        // set filtered output image to outputImageView

        // if camera is running, just change the filter name
        guard let filter = filter else {
            print("filter is nil in \(#function)")
            return
        }
        
        self.currentFilter = filter
        
        // if camera is not running
        if !session.isRunning {
            showGif()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension SatoCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /** Called the specified times (FPS) every second. Converts sample buffer into CIImage. 
     Applies filter to it. Draw the CIImage into CIContext to update GLKView.
     In background, store CIImages into array one by one. Resizing should be done in background.*/
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        
        CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false)
        
        // Store in background thread
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            self.didOutputSampleBufferMethodCallCount += 1
            if self.didOutputSampleBufferMethodCallCount % self.currentLiveGifPreset.frameCaptureFrequency == 0 {
                
                if let url = sampleBuffer.saveFrameToDisk() {
                    self.originalURLs.append(url)
                    
                    //if let resizedUrl = self.resize(image: url, maxSize: self.maxPixelSize) {
                    if let resizedUrl = url.resize(maxSize: self.maxPixelSize) {
                        self.resizedURLs.append(resizedUrl)
                    } else {
                        print("failed to get resized URL")
                    }
                    
                    if !self.isSnappedGif {
                        // pre-saving
                        if self.originalURLs.count > self.currentLiveGifPreset.liveGifFrameTotalCount / 2 {
                            // Remove the first item in the array
                            let firstItem = self.originalURLs.removeFirst()
                            //let firstItem = self.originalURLs[0]
                            //self.originalURLs.remove(at: 0)
                            do {
                                // Remove data at the first URL. If this fails data, the data should be collected at some point.
                                try self.fileManager.removeItem(at: firstItem)
                            } catch let e {
                                print(e)
                            }
                        }
                        
                        if self.resizedURLs.count > self.currentLiveGifPreset.liveGifFrameTotalCount / 2 {
                            let firstItem = self.resizedURLs.removeFirst()
                            //let firstItem = self.resizedURLs[0]
                            //self.resizedURLs.remove(at: 0)
                            do {
                                try self.fileManager.removeItem(at: firstItem)
                            } catch let e {
                                print(e)
                            }
                        }
                        
                    } else {
                        // post-saving
                        
                        if self.originalURLs.count >= self.currentLiveGifPreset.liveGifFrameTotalCount {
                            DispatchQueue.main.async { [unowned self] in
                                // UI change has to be in main thread
                                self.stopLiveGif()
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
        
        videoGLKPreview?.bindDrawable()
        
        // Prepare CIContext with EAGLContext
        if eaglContext != EAGLContext.current() {
            EAGLContext.setCurrent(eaglContext)
        }

        ciContext?.draw(filteredImage, in: videoGLKPreviewViewBounds!, from: sourceImage.extent)
        videoGLKPreview?.display()
    }
}
