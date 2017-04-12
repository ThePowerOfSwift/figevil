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
import MobileCoreServices // for HDD
import Photos // for HDD saving

/** Init with frame and set yourself (client) to cameraOutput delegate and call start(). */
class SatoCamera: NSObject {
    
    /** To use, SatoCamera.shared, 
     1. conform to SatoCameraOutput protocol.
     2. set your VC to shared.cameraOutput.
     3. call start(). */
    static let shared: SatoCamera = SatoCamera(frame: UIScreen.main.bounds)
    
    // MARK: AVCaptureSession
    fileprivate var videoDevice: AVCaptureDevice?
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var videoDataOutput = AVCaptureVideoDataOutput()
    internal var session = AVCaptureSession()
    internal var sessionQueue = DispatchQueue(label: "sessionQueue")
    /** Frame of sampleBufferView of CameraOutput delegate. Should be set when being initialized. */
    fileprivate var frame: CGRect
    
    // MARK: OpenGL for live camera
    fileprivate var liveCameraGLKView: GLKView!
    fileprivate var liveCameraCIContext: CIContext?
    fileprivate var liveCameraEaglContext: EAGLContext?
    fileprivate var liveCameraGLKViewBounds = CGRect()
    
    // MARK: OpenGL for gif preview
    fileprivate var gifGLKView: GLKView!
    fileprivate var gifCIContext: CIContext?
    fileprivate var gifEaglContext: EAGLContext?
    fileprivate var gifGLKViewPreviewViewBounds = CGRect()
    
    // MARK: State
    fileprivate var cameraFace: CameraFace = .Back
    fileprivate var currentFilter: Filter = Filter.shared.list[0]
    fileprivate var light = Light()
    fileprivate var currentLiveGifPreset: LiveGifPreset = LiveGifPreset()
    
    // MARK: User action state
    fileprivate var isRecording: Bool = false
    internal var isSnappedGif: Bool = false
    
    // MARK: Delegate
    /** Delegate for SatoCamera. liveCameraGLKView will be added subview to sampleBufferOutput in dataSource. */
    var cameraOutput: SatoCameraOutput? {
        willSet {
            session.stopRunning()
            self.cameraOutput = nil
        }
        
        didSet {
            liveCameraGLKView.removeFromSuperview()
            gifGLKView.removeFromSuperview()
            guard let cameraOutput = cameraOutput else {
                print("Error: video preview or camera output is nil")
                return
            }
            guard let sampleBufferOutput = cameraOutput.sampleBufferView, let gifOutputView = cameraOutput.gifOutputView else {
                print("Error: sample buffer view or gif output view is nil")
                return
            }
            sampleBufferOutput.addSubview(liveCameraGLKView)
            gifOutputView.addSubview(gifGLKView)
        }
    }
    
    // MARK: Result of session configuration
    private enum SessionSetupResult {
        case success
        case configurationFailed
        case notAuthorized
    }
    private var setupResult: SessionSetupResult = .success
    
    // MARK: Orientation
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
    
    // MARK: Save frame to HDD
    /** count variable to count how many times the method gets called */
    fileprivate var didOutputSampleBufferMethodCallCount: Int = 0
    internal var frameSavingSerialQueue = DispatchQueue(label: "frameSavingSerialQueue")    /** To be rendered. */
    fileprivate var filteredUIImages = [UIImage]()
    fileprivate var originalURLs = [URL]()
    fileprivate var resizedURLs = [URL]()
    fileprivate var renderedURLs = [URL]()
    fileprivate let fileManager = FileManager.default
    /** Documents/thumbnail/{UUID}. */
    fileprivate var thumbnailUrlPath: URL {
        let path = URL.pathWith(subpath: "/thumbnail")
        return URL(fileURLWithPath: path)
    }
    /** Documents/resized/{UUID}. */
    var resizedUrlPath: URL {
        let path = URL.pathWith(subpath: "/resized")
        return URL(fileURLWithPath: path)
    }
    /** Documents/original/{UUID}. */
    var originalUrlPath: URL {
        let path = URL.pathWith(subpath: "/original")
        return URL(fileURLWithPath: path)
    }
    func getMaxPixel(scale: Double) -> Int {
        let longerSide = Double(max(frame.height, frame.width))
        return Int(longerSide / scale)
    }
    // scale 3 is around 500KB
    // scale 2 is around 800KB ~ 1000KB
    // scale 2.1 is 900KB with text and drawing
    // scale 1 is around 3000K
    //let pixelSizeForMessage = getMaxPixel(scale: 2.1) // 350 on iPhone 7 plus, 317 on iPhone 6
    //let pixelSizeForThumbnail = getMaxPixel(scale: 3) // 245 on iPhone 7 plus, 222 on iphone 6
    var messagePixelSize = Camera.Size.MessagePixelSize
    var thumbnailPixelSize = Camera.Size.ThumbnailPixelSize
    var shouldSaveFrame: Bool {
        return self.didOutputSampleBufferMethodCallCount % self.currentLiveGifPreset.frameCaptureFrequency == 0
    }
    
    // MARK: - Setups
    init(frame: CGRect) {
        self.frame = frame
        //http://stackoverflow.com/questions/29619846/in-swift-didset-doesn-t-fire-when-invoked-from-init
        super.init()
        setupliveCameraGLKView()
        setupGifGLKView()
        setupOpenGL()
        setupSession()
    }
    
    func setupliveCameraGLKView() {
        guard let liveCameraEaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
            print("Error: eaglContext is nil")
            setupResult = .configurationFailed
            return
        }
        self.liveCameraEaglContext = liveCameraEaglContext
        liveCameraGLKView = GLKView(frame: frame, context: liveCameraEaglContext)
        liveCameraGLKView.enableSetNeedsDisplay = false // disable normal UIView drawing cycle
        liveCameraGLKView.frame = frame
        liveCameraGLKView.bindDrawable()
        liveCameraGLKViewBounds = CGRect.zero
        liveCameraGLKViewBounds.size.width = CGFloat(liveCameraGLKView.drawableWidth) // 1334 pixels
        liveCameraGLKViewBounds.size.height = CGFloat(liveCameraGLKView.drawableHeight) // 749 pixels
        liveCameraCIContext = CIContext(eaglContext: liveCameraEaglContext)
    }
    
    func setupGifGLKView() {
        guard let gifEaglContext =  EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
            print("Error: failed to create EAGLContext in \(#function)")
            return
        }
        self.gifEaglContext = gifEaglContext
        gifGLKView = GLKView(frame: frame, context: gifEaglContext)
        gifGLKView.enableSetNeedsDisplay = false
        gifGLKView.frame = frame
        gifGLKView.bindDrawable()
        gifGLKViewPreviewViewBounds = CGRect.zero
        gifGLKViewPreviewViewBounds.size.width = CGFloat(gifGLKView.drawableWidth)
        gifGLKViewPreviewViewBounds.size.height = CGFloat(gifGLKView.drawableHeight)
        gifCIContext = CIContext(eaglContext: gifEaglContext)
    }
    
    /** Authorize camera usage. */
    func askUserCameraAccessAuthorization(completion: ((_ authorized: Bool)->())?) {
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) != AVAuthorizationStatus.authorized {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                completion?(granted)
            })
        } else {
            completion?(true)
        }
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
    
    internal func setupSession() {
        
        // Get video device
        guard let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else {
            print("Error: video device is nil")
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
        
        // setup video output setting
        let outputSettings: [AnyHashable : Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.videoSettings = outputSettings
        // Ensure frames are delivered to the delegate in order
        // http://stackoverflow.com/questions/31775356/modifying-uiview-above-glkview-causing-crashes
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // setup input object with device
        // THIS CODE HAS TO BE BEFORE THE FRAME RATE  CONFIG
        // http://stackoverflow.com/questions/20330174/avcapture-capturing-and-getting-framebuffer-at-60-fps-in-ios-7
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                print("Error: video device input cannot be added to session.")
                setupResult = .configurationFailed
            }
        } catch {
            print("Error: Failed to instantiate input object")
            setupResult = .configurationFailed
        }
        
        session.beginConfiguration()
        
        if videoDevice.hasTorch && videoDevice.isTorchAvailable {
            do {
                try videoDevice.lockForConfiguration()
                //videoDevice.torchMode = torchState
                videoDevice.torchMode = light.torchState
                videoDevice.unlockForConfiguration()
            } catch {
                print("Error: failed to lock device")
                setupResult = .configurationFailed
            }
        }
        
        // Add output object to session
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        } else {
            print("Error: cannot add video data output")
            setupResult = .configurationFailed
        }
        
        setupVideoOrientation()
        
        // Assemble all the settings together
        session.commitConfiguration()
        // Check if camera usage is authorized by user before starting to run
        sessionQueue.suspend()
        askUserCameraAccessAuthorization { (authorized: Bool) in
            if authorized {
                print("camera access authorized")
                self.setupResult = .success
                self.sessionQueue.resume()
            } else {
                self.setupResult = .configurationFailed
                print("Error: camera access failed to authorize")
            }
        }
    }
    
    /** Change the orientation of data recieved by AVCaptureVideoData. */
    func setupVideoOrientation() {
        if let connection = videoDataOutput.connection(withMediaType: AVMediaTypeVideo) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
                
                if cameraFace == CameraFace.Front {
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                }
            }
        }
    }
    
    internal func tapToFocusAndExposure(touch: UITouch) {
        let touchPoint = touch.location(in: liveCameraGLKView)
        // https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
        // convert device point to image point in unit
        let convertedX = touchPoint.y / frame.height
        let convertedY = (frame.width - touchPoint.x) / frame.width
        let convertedPoint = CGPoint(x: convertedX, y: convertedY)
        focus(with: .autoFocus, exposureMode: .autoExpose, at: convertedPoint)
        
        // feedback rect view
        let feedbackView = UIView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 50, height: 50)))
        feedbackView.center = touchPoint
        feedbackView.layer.borderColor = UIColor.white.cgColor
        feedbackView.layer.borderWidth = 2.0
        feedbackView.layer.cornerRadius = feedbackView.frame.width / 2
        feedbackView.clipsToBounds = true
        feedbackView.backgroundColor = UIColor.clear
        DispatchQueue.main.async {
            self.cameraOutput?.sampleBufferView?.addSubview(feedbackView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                // Put your code which should be executed with a delay here
                feedbackView.removeFromSuperview()
            })
        }
    }
    
    private func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at unitPoint: CGPoint) {
        sessionQueue.async { [unowned self] in
            if let device = self.videoDevice {
                do {
                    try device.lockForConfiguration()
                    /*
                     Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                     Call set(Focus/Exposure)Mode() to apply the new point of interest.
                     */
                    if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                        device.focusPointOfInterest = unitPoint
                        device.focusMode = focusMode
                    }
                    if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                        device.exposurePointOfInterest = unitPoint
                        device.exposureMode = exposureMode
                    }
                    device.unlockForConfiguration()
                }
                catch {
                    print("Error: Could not lock device for configuration: \(error)")
                }
            }
        }
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
    
    
    // MARK: - Camera Settings
    internal func toggleFlash() -> String {
        return light.toggleFlash(videoDevice: videoDevice)
    }
    
    internal func toggleTorch() -> String {
        return light.toggleTorch(videoDevice: videoDevice)
    }
    
    /** Toggles back camera or front camera. */
    internal func toggleCamera() {
        let cameraDevice = AVCaptureDevice.getCameraDevice(cameraFace: &cameraFace)
        didOutputSampleBufferMethodCallCount = 0
        session.beginConfiguration()
        session.removeInput(videoDeviceInput)
        videoDevice = cameraDevice
        // setup input object with device
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            // Add it to session
            if let videoDeviceInput = videoDeviceInput {
                session.addInput(videoDeviceInput)
            } else {
                print("Error: videoDeviceInput is nil")
            }
        } catch {
            print("Error: Failed to instantiate input object")
        }
        setupVideoOrientation()
        session.commitConfiguration()
    }
    
    // MARK: - Camera Controls
    internal func start() {
        session.startRunning()
        if !session.isRunning {
            print("Error: camera failed to run.")
        }
    }
    
    internal func stop() {
        session.stopRunning()
    }
    
    /** Set to the initial state. */
    internal func reset() {
        originalURLs.removeAll()
        resizedURLs.removeAll()
        renderedURLs.removeAll()
        filteredUIImages.removeAll()
        cameraOutput?.sampleBufferView?.isHidden = false
        cameraOutput?.gifOutputView?.isHidden = true
        didOutputSampleBufferMethodCallCount = 0
        start()
    }

    /** Render everything together. */
    internal func render(imageUrls: [URL], renderItems: [UIImage]?) -> [URL] {
        var filteredResizedUIImages = [UIImage]()
        let ciContext = CIContext()
        for url in imageUrls {
            if let image = url.makeUIImage(filter: currentFilter.filter, context: ciContext) {
                filteredResizedUIImages.append(image)
            } else {
                print("Error: resized image is nil in \(#function)")
            }
        }
        
        var urls = [URL]()
        for image in filteredResizedUIImages {
            let renderedImage = image.render(items: renderItems, frame: frame)
            guard let cgImage = renderedImage.cgImage else {
                print("Error: Could not get cgImage from rendered UIImage in \(#function)")
                break
            }
            guard let url = cgImage.saveToDisk(cgImagePropertyOrientation: cgImageOrientation) else {
                print("Error: Could not save cgImage to disk in \(#function)")
                break
            }
            urls.append(url)
        }
        return urls
    }

    internal func save(renderItems: [UIImage]?, completion: ((_ saved: Bool, _ savedUrl: SavedURLs?, _ fileSize: String?) -> ())?) {
        renderedURLs = render(imageUrls: resizedURLs, renderItems: renderItems)
        var thumbnailURLs = [URL]()
        var messageURLs = [URL]()
        for url in renderedURLs {
            if let thumbnailURL = url.resize(maxSize: thumbnailPixelSize, destinationURL: resizedUrlPath) {
                thumbnailURLs.append(thumbnailURL)
            } else {
                print("Error: resizing to thumbnail failed in \(#function)")
            }
            
            if let messageURL = url.resize(maxSize: messagePixelSize, destinationURL: resizedUrlPath) {
                messageURLs.append(messageURL)
            } else {
                print("Error: resizing to message failed in \(#function)")
            }
        }
        
        let path = String(Date().timeIntervalSinceReferenceDate)
        let thumbnailURL = URL.thumbnailURL(path: path)
        let messageURL = URL.messageURL(path: path)
        let originalURL = URL.originalURL(path: path)
        
        let savedURLs = SavedURLs(thumbnail: thumbnailURL, message: messageURL, original: originalURL)
        
        if thumbnailURLs.createGif(frameDelay: 0.5, destinationURL: thumbnailURL) {
            print("thumbnail gif URL filesize: \(thumbnailURL.filesize!)")
        } else {
            print("Error: thumbnail gif URL failed to save in \(#function)")
        }
        
        if messageURLs.createGif(frameDelay: 0.5, destinationURL: messageURL) {
            print("message gif URL filesize: \(messageURL.filesize!)")
        } else {
            print("Error: message gif URL failed to save in \(#function)")
        }
        
        if renderedURLs.createGif(frameDelay: 0.5, destinationURL: originalURL) {
            print("original gif URL filesize: \(originalURL.filesize!)")
            PHPhotoLibrary.requestAuthorization
                { (status) -> Void in
                    switch (status)
                    {
                    case .authorized:
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: originalURL)
                        }, completionHandler: { (saved: Bool, error: Error?) in
                            if saved {
                                completion?(true, savedURLs, originalURL.filesize!)
                            } else {
                                print("Error: did not save gif")
                                completion?(false, nil, nil)
                            }
                        })
                    case .denied:
                        print("Error: User denied")
                    default:
                        print("Error: Restricted")
                    }
            }

        } else {
            print("Error: original gif URL failed to save in \(#function)")
        }
    }
    
    /** Share message size gif. */
    func share(renderItems: [UIImage], completion: ((_ saved: Bool, _ savedUrl: URL?) -> ())?) {
        renderedURLs = render(imageUrls: resizedURLs, renderItems: renderItems)
        var messageURLs = [URL]()
        for url in renderedURLs {
            
            if let messageURL = url.resize(maxSize: messagePixelSize, destinationURL: resizedUrlPath) {
                messageURLs.append(messageURL)
            } else {
                print("Error: resizing to message failed in \(#function)")
            }
        }
        
        let path = NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate))
        let url = URL(fileURLWithPath: path)
        
        let success = messageURLs.createGif(frameDelay: 0.5, destinationURL: url)
        
        if success {
            print("gif is saved to \(url). Filesize is \(String(describing: url.filesize!))")
            completion?(success, url)
        } else {
            print("Error: gif file is not saved in \(#function)")
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
    
    /** Stops image post-storing. Calls showGif to show gif.*/
    fileprivate func stopLiveGif() {
        isSnappedGif = false
        cameraOutput?.didLiveGifStop?()
        deviceOrientation = UIDevice.current.orientation
        cameraOutput?.gifOutputView?.isHidden = false
        stop()
        //showGif()
        showGifWithGLKView()
    }
    
    /** Creates an image view with images for animation. Show the image view on output image view. */
    func showGif() {
        // make resized images from originals here
        var resizedTempURLs = [URL]()
        let resizedMaxPixel = getMaxPixel(scale: 1)
        for url in originalURLs {
            if let resizedUrl = url.resize(maxSize: resizedMaxPixel, destinationURL: resizedUrlPath) {
                resizedTempURLs.append(resizedUrl)
            } else {
                print("Error: failed to get resized URL")
            }
        }
        
        resizedURLs = resizedTempURLs
        
        if let gifImageView = makeGif(urls: resizedTempURLs, filter: currentFilter.filter, animationDuration: currentLiveGifPreset.gifDuration) {
            if let cameraOutput = cameraOutput {
                if let outputImageView = cameraOutput.gifOutputView {
                    outputImageView.isHidden = false
                    for subview in outputImageView.subviews {
                        subview.removeFromSuperview()
                    }
                }
            }
            cameraOutput?.gifOutputView?.addSubview(gifImageView)
            cameraOutput?.gifOutputView?.sendSubview(toBack: gifImageView)
            gifImageView.startAnimating()
        } else {
            print("Error: gifImageView is nil")
        }
    }
    
    func showGifWithGLKView() {
        // make resized images from originals here
        var resizedTempURLs = [URL]()
        let resizedMaxPixel = getMaxPixel(scale: 1)
        for url in originalURLs {
            if let resizedUrl = url.resize(maxSize: resizedMaxPixel, destinationURL: resizedUrlPath) {
                resizedTempURLs.append(resizedUrl)
            } else {
                print("Error: failed to get resized URL")
            }
        }
        
        resizedURLs = resizedTempURLs
        
        var resizedCIImages = [CIImage]()
        for url in resizedTempURLs {
            guard let sourceCIImage = url.cgImage?.ciImage else {
                print("Error: cgImage is nil in \(#function)")
                return
            }
            resizedCIImages.append(sourceCIImage)
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async { [unowned self] in
            self.gifGLKView.bindDrawable()
    
            if self.gifEaglContext != EAGLContext.current() {
                EAGLContext.setCurrent(self.gifEaglContext)
            }
            
            self.setupOpenGL()
            while !self.session.isRunning {
                if self.session.isRunning {
                    break
                }
                
                self.setupOpenGL()
                for image in resizedCIImages {
                    if self.session.isRunning {
                        break
                    }
                    if let filter = self.currentFilter.filter {
                        filter.setValue(image, forKey: kCIInputImageKey)
                        if let outputImage = filter.outputImage {
                            self.gifCIContext?.draw(outputImage, in: self.gifGLKViewPreviewViewBounds, from: image.extent)

                        }
                    } else {
                        self.gifCIContext?.draw(image, in: self.gifGLKViewPreviewViewBounds, from: image.extent)
                    }
                    
                    self.gifGLKView.display()
                    usleep(useconds_t(self.currentLiveGifPreset.sleepDuration))
                }
            }
        }
    }

    /** Make a gif image view from urls. */
    func makeGif(urls: [URL], filter: CIFilter?, animationDuration: TimeInterval) -> UIImageView? {
        
        filteredUIImages.removeAll()
        let ciContext = CIContext() // Reuse this context.
        for url in urls {
            
            if let image = url.makeUIImage(filter: filter, context: ciContext) {
                filteredUIImages.append(image)
            } else {
                print("Error: original image is nil in \(#function)")
            }
        }
        
        let imageView = UIImageView(frame: frame)
        imageView.animationImages = filteredUIImages
        imageView.animationRepeatCount = 0
        imageView.animationDuration = animationDuration
        
        return imageView
    }
}

// MARK: - Other types
@objc protocol SatoCameraOutput {
    /** Show the filtered output image view. */
    var gifOutputView: UIView? { get set }
    /** Show the live preview. GLKView is added to this view. */
    var sampleBufferView: UIView? { get }
    @objc optional func didLiveGifStop()
}

/** Indicate camera state. */
enum CameraFace {
    case Back
    case Front
}

/** Holds URLs saved in SatoCamera. */
struct SavedURLs {
    var thumbnail: URL
    var message: URL
    var original: URL
}

/** Gif preset. */
struct LiveGifPreset {
    /** has to be 0 < gifFPS <= 15 and 30 */
    var gifFPS: Int
    var gifDuration: TimeInterval
    var frameCaptureFrequency: Int {
        return Int(sampleBufferFPS) / gifFPS
    }
    var sampleBufferFPS: Int32 = Camera.LiveGifPreset.SampleBufferFPS
    var liveGifFrameTotalCount: Int {
        return Int(gifDuration * Double(gifFPS))
    }
    /** The amount of time each frame stays. */
    var frameDelay: Double {
        return Double(gifDuration) / Double(liveGifFrameTotalCount)
    }
    /** Used in usleep() function to pause outputting filtered CIImage. 1000000 = 1 second in usleep().*/
    var sleepDuration: Double {
        return frameDelay * 1000000
    }
    init(gifFPS: Int, gifDuration: TimeInterval) {
        self.gifFPS = gifFPS
        self.gifDuration = gifDuration
    }
    init() {
        self.gifFPS = Camera.LiveGifPreset.GifFPS
        self.gifDuration = Camera.LiveGifPreset.GifDuration
    }
}

extension URL {
    var cgImage: CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil) else {
            print("Error: CGImage is nil in \(#function)")
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
    
    //try print out each CGImage to see if max pixel effect the size
    
    /** Resize an image at a given url. */
    func resize(maxSize: Int, destinationURL: URL) -> URL? {
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
        
        guard let imageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypeJPEG, 1, nil) else {
            print("Error: cannot create image destination")
            return nil
        }
        
        CGImageDestinationAddImage(imageDestination, resizedImage, nil)
        
        if !CGImageDestinationFinalize(imageDestination) {
            print("Error: cannot finalize and write image destination for resize")
            return nil
        }
        
        return destinationURL
    }
    
    /** Make UIImage from URL*/
    func makeUIImage(filter: CIFilter?, context: CIContext) -> UIImage? {
        guard let sourceCIImage = self.cgImage?.ciImage else {
            print("Error: cgImage is nil in \(#function)")
            return nil
        }
        
        var filteredCIImage = CIImage()
        if let filter = filter {
            
            filter.setValue(sourceCIImage, forKeyPath: kCIInputImageKey)
            if let image = filter.outputImage {
                filteredCIImage = image
            } else {
                print("Error: failed to make filtered image in \(#function)")
                filteredCIImage = sourceCIImage
            }
            
        } else {
            filteredCIImage = sourceCIImage
        }
        
        // use cgImage.ciImage.extent because the new ciImage does not have extent
        let filteredCGImage = context.createCGImage(filteredCIImage, from: sourceCIImage.extent)
        
        let uiImage = UIImage(cgImage: filteredCGImage!)
        return uiImage
    }
    
    /** Create path at the specified directory under document directory. subpath will be something like /original or /resized */
    static func pathWith(subpath: String) -> String {
        let intermediate​Path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0].appending(subpath)
        let intermediateUrl = URL(fileURLWithPath: intermediate​Path)
        
        do {
            try FileManager.default.createDirectory(at: intermediateUrl, withIntermediateDirectories: true, attributes: nil)
        } catch let e {
            print(e)
        }
        
        if FileManager.default.fileExists(atPath: intermediate​Path) {
            return intermediate​Path.appending("/\(UUID().uuidString)")
        }
        
        print("Error: failed to make path in \(#function)")
        return NSTemporaryDirectory().appending(UUID().uuidString)
    }
    
    static func thumbnailURL(path: String) -> URL {
        var url: URL
        if let gifDirectoryURL = UserGenerated.gifDirectoryURL {

            let path = path.appending(UserGenerated.thumbnailTag).appending(".gif")
            url = gifDirectoryURL.appendingPathComponent(path, isDirectory: false)

        } else {
            url = URL(fileURLWithPath: NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate)).appending(".gif"))
            print("Error: failed to create thumbnail URL")
        }
        return url
    }
    
    static func messageURL(path: String) -> URL {
        var url: URL
        if let gifDirectoryURL = UserGenerated.gifDirectoryURL {

            let path = path.appending(UserGenerated.messageTag).appending(".gif")
            url = gifDirectoryURL.appendingPathComponent(path, isDirectory: false)

        } else {
            url = URL(fileURLWithPath: NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate)).appending(".gif"))
            print("Error: failed to create thumbnail URL")
        }
        return url
    }
    
    static func originalURL(path: String) -> URL {
        var url: URL
        if let gifDirectoryURL = UserGenerated.gifDirectoryURL {
            
            let path = path.appending(UserGenerated.originalTag).appending(".gif")
            url = gifDirectoryURL.appendingPathComponent(path, isDirectory: false)
            
        } else {
            url = URL(fileURLWithPath: NSTemporaryDirectory().appending(String(Date().timeIntervalSinceReferenceDate)).appending(".gif"))
            print("Error: failed to create thumbnail URL")
        }
        return url
    }
}

extension UIImage {
    func render(items: [UIImage]?, frame: CGRect) ->UIImage {
        UIGraphicsBeginImageContext(frame.size)
        if let images = items {
            self.draw(in: frame)
            
            for image in images {
                image.draw(in: frame)
            }

            if let renderedImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                return renderedImage
            }
        }
        UIGraphicsEndImageContext()
        return self
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
    func createGif(loopCount: Int = 0, frameDelay: Double, destinationURL: URL) -> Bool {
        let imageURLs = self as! [URL]
        // Data check
        if imageURLs.count <= 0 {
            return false
        }
        
        // Create write-to destination
        guard let gifDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypeGIF, imageURLs.count, nil) else {
            print("Error: cannot create image destination is nil")
            return false
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
            return false
        } else {
            print("Saved gif to \(destinationURL.path)")
        }
        return true
    }
}

extension AVCaptureDevice {
    /** Get camera device based on cameraState. */
    class func getCameraDevice(cameraFace: inout CameraFace) -> AVCaptureDevice {
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
}

// MARK: - FilterImageEffectDelegate
extension SatoCamera: FilterImageEffectDelegate {
    
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?) {

        guard let filter = filter else {
            print("filter is nil in \(#function)")
            return
        }
        
        self.currentFilter = filter
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension SatoCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        // Save and remove serially and asynchronously
        frameSavingSerialQueue.async { [unowned self] in
            
            self.didOutputSampleBufferMethodCallCount += 1
            if self.shouldSaveFrame {
                
                if let url = sampleBuffer.saveFrameToDisk(outputURL: self.originalUrlPath) {
                    self.originalURLs.append(url)
                    
                    if !self.isSnappedGif {
                        // pre-saving
                        if self.originalURLs.count > self.currentLiveGifPreset.liveGifFrameTotalCount / 2 {
                            // Remove the first item in the array
                            let firstItem = self.originalURLs.removeFirst()
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
                                self.stopLiveGif()
                            }
                        }
                    }
                }
            }
        }
    
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error: image buffer is nil")
            return
        }
        let sourceImage: CIImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // filteredImage has the same address as sourceImage
        guard let filteredImage = currentFilter.generateFilteredCIImage(sourceImage: sourceImage) else {
            print("Error: filtered image is nil in \(#function)")
            return
        }
        
        liveCameraGLKView.bindDrawable()
        
        // Prepare CIContext with EAGLContext
        if liveCameraEaglContext != EAGLContext.current() {
            EAGLContext.setCurrent(liveCameraEaglContext)
        }
        setupOpenGL()
        
        liveCameraCIContext?.draw(filteredImage, in: liveCameraGLKViewBounds, from: sourceImage.extent)
        liveCameraGLKView.display()
    }
}
