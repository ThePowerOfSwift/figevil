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
    fileprivate var videoGLKPreview: GLKView?
    fileprivate var videoDevice: AVCaptureDevice?
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var ciContext: CIContext?
    fileprivate var eaglContext: EAGLContext?
    /** stores GLKView's drawableWidth (The width, in pixels, of the underlying framebuffer object.) */
    fileprivate var videoGLKPreviewViewBounds: CGRect?
    fileprivate var captureSession: AVCaptureSession?
    /** Frame of sampleBufferView of CameraOutput delegate. Should be set when being initialized. */
    fileprivate var frame: CGRect
    
    // MARK: State
    fileprivate var cameraFace: CameraFace = .Back
    fileprivate var currentFilter: Filter = Filter.list()[0]
    fileprivate var light = Light()

    // MARK: Results
    /** Stores the result gif object. */
    fileprivate var gif: Gif?
    /** Stores captured CIImages*/
    fileprivate var unfilteredCIImages: [CIImage] = [CIImage]()
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
    
    // MARK: Transform
    /** CGAffineTransfrom when it's back camera. */
    var backCameraTransform: CGAffineTransform {
        return CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
    }
    
    /** CGAffineTransfrom when it's front camera. */
    var frontCameraTransform: CGAffineTransform {
        let rotation = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
        let flip = CGAffineTransform(scaleX: -1.0, y: 1.0)
        let transform = rotation.concatenating(flip)
        return transform
    }
    
    // Gif setting
    var currentLiveGifPreset: LiveGifPreset = LiveGifPreset(gifFPS: 5, liveGifDuration: 3)
    
    // MARK: - Setups
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
        videoGLKPreview.transform = backCameraTransform
        
        // Always set frame after transformation
        videoGLKPreview.frame = frame

        videoGLKPreview.bindDrawable()
        videoGLKPreviewViewBounds = CGRect.zero
        // drawable width The width, in pixels, of the underlying framebuffer object.
        videoGLKPreviewViewBounds?.size.width = CGFloat(videoGLKPreview.drawableWidth) // 1334 pixels
        videoGLKPreviewViewBounds?.size.height = CGFloat(videoGLKPreview.drawableHeight) // 749 pixels
        
        ciContext = CIContext(eaglContext: eaglContext)
        setupOpenGL()
        
        initialStart()
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
    
    var captureSessionQueue: DispatchQueue = DispatchQueue.main
    
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
        //let captureSessionQueue = DispatchQueue.main
        // Set delegate to self for didOutputSampleBuffer
        videoDataOutput.setSampleBufferDelegate(self, queue: captureSessionQueue)
        
        // Discard late video frames not to cause lag and be slow
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
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
                //videoDevice.torchMode = torchState
                videoDevice.torchMode = light.torchState
                videoDevice.unlockForConfiguration()
            } catch {
                
            }
        }
        
        // Add output object to session
        captureSession.addOutput(videoDataOutput)
        
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
        let adjustedCoordinatePoint = CGPoint(x: frame.width - touchPoint.y, y: touchPoint.x)

        guard let videoDevice = videoDevice else {
            print("video device is nil")
            return
        }
        
        // (1 - ) changes the origin to top, right
        // You pass a CGPoint where {0,0} represents the top left of the picture area, and {1,1} represents the bottom right in landscape mode with the home button on the right—this applies even if the device is in portrait mode.
        // https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
        let adjustedPoint = CGPoint(x: 1 - adjustedCoordinatePoint.x / frame.width, y: adjustedCoordinatePoint.y / frame.height)
        
        captureSessionQueue.async { [unowned self] in
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
            self.cameraOutput?.sampleBufferView?.addSubview(feedbackView)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                // Put your code which should be executed with a delay here
                feedbackView.removeFromSuperview()
            })
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
        captureSession?.startRunning()
    }
    
    internal func stop() {
        cameraOutput?.sampleBufferView?.isHidden = true
        captureSession?.stopRunning()
    }
    
    /** Set to the initial state. */
    internal func reset() {
        unfilteredCIImages.removeAll()
        cameraOutput?.sampleBufferView?.isHidden = false
        didOutputSampleBufferMethodCallCount = 0
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
        stop()
        showGif()
    }
    
    /** Creates an image view with images for animation. Show the image view on output image view. */
    func showGif() {
        let gif = Gif(originalCIImages: unfilteredCIImages, scale: 0, frame: frame, filter: currentFilter, preset: currentLiveGifPreset)
        
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

// MARK: - FilterImageEffectDelegate
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

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension SatoCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /** Called the specified times (FPS) every second. Converts sample buffer into CIImage. 
     Applies filter to it. Draw the CIImage into CIContext to update GLKView.
     In background, store CIImages into array one by one. Resizing should be done in background.*/
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if cameraFace == CameraFace.Back {
            videoGLKPreview?.transform = backCameraTransform
        } else {
            videoGLKPreview?.transform = frontCameraTransform
        }
        
        // Store in background thread
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            self.didOutputSampleBufferMethodCallCount += 1
            if self.didOutputSampleBufferMethodCallCount % self.currentLiveGifPreset.frameCaptureFrequency == 0 {
                
                // get deep copied CIImage from sample buffer so that the ciimage has no reference to sample buffer anymore
                if let deepCopiedCIImage = sampleBuffer.ciImage {
                    if self.isRecording {
                        self.unfilteredCIImages.append(deepCopiedCIImage)
                    } else {
                        
                        // detect snap user action
                        if !self.isSnappedGif {
                            self.unfilteredCIImages.append(deepCopiedCIImage)
                            
                            if self.unfilteredCIImages.count == self.currentLiveGifPreset.liveGifFrameTotalCount / 2 {
                                self.unfilteredCIImages.remove(at: 0)
                            }
                        } else {
                            
                            // if snapped, start post-storing
                            self.unfilteredCIImages.append(deepCopiedCIImage)
                            if self.unfilteredCIImages.count == self.currentLiveGifPreset.liveGifFrameTotalCount {
                                DispatchQueue.main.async { [unowned self] in
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
        
        videoGLKPreview?.bindDrawable()
        
        // Prepare CIContext with EAGLContext
        if eaglContext != EAGLContext.current() {
            EAGLContext.setCurrent(eaglContext)
        }

        ciContext?.draw(filteredImage, in: videoGLKPreviewViewBounds!, from: sourceImage.extent)
        videoGLKPreview?.display()
    }
}
