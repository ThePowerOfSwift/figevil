diff --git a/figevil/SatoCamera.swift b/figevil/SatoCamera.swift
index 9eb2b25..5bc9933 100644
--- a/figevil/SatoCamera.swift
+++ b/figevil/SatoCamera.swift
@@ -13,14 +13,14 @@ import QuartzCore
 import MobileCoreServices // for HDD
 import Photos // for HDD saving
 
-/** Init with frame and set yourself (client) to cameraOutput delegate and call start(). */
+/** Init with frame and set yourself (client) to cameraOutput delegate and call start().
+To use, SatoCamera.shared,
+1. conform to SatoCameraOutput protocol.
+2. set your VC to shared.cameraOutput.
+3. call start(). */
 class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
     
-    /** To use, SatoCamera.shared, 
-     1. conform to SatoCameraOutput protocol.
-     2. set your VC to shared.cameraOutput.
-     3. call start(). */
-    static let shared: SatoCamera = SatoCamera(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)))
+    static let shared: SatoCamera = SatoCamera()
     
     // MARK: AVCaptureSession
     fileprivate var videoDevice: AVCaptureDevice?
@@ -29,19 +29,41 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
     internal var session = AVCaptureSession()
     internal var sessionQueue = DispatchQueue(label: "sessionQueue")
     /** Frame of sampleBufferView of CameraOutput delegate. Should be set when being initialized. */
-    fileprivate var frame: CGRect = CGRect.zero
+    var captureSize: Camera.screen = Camera.screen.square {
+        didSet {
+            if oldValue != captureSize {
+                let frame = CGRect(origin: CGPoint.zero, size: captureSize.size())
+                liveCameraGLKView.resize(frame: frame)
+                gifGLKView.resize(frame: frame)
+            }
+        }
+    }
     
-    // MARK: OpenGL for live camera
-    fileprivate var liveCameraGLKView: GLKView!
-    fileprivate var liveCameraCIContext: CIContext?
-    fileprivate var liveCameraEaglContext: EAGLContext?
-    fileprivate var liveCameraGLKViewBounds = CGRect()
+    /// Struct that represents GLKView and underlying EAGLContext/CIContext
+    private struct CameraGLKView {
+        var eaglContext: EAGLContext!
+        var glkView: GLKView!
+        var ciContext: CIContext!
+        var drawFrame: CGRect!
+        
+        init(frame: CGRect, context: EAGLContext) {
+            eaglContext = context
+            resize(frame: frame)
+            ciContext = CIContext(eaglContext: context)
+        }
+        
+        mutating func resize(frame: CGRect) {
+            glkView = GLKView(frame: frame, context: eaglContext)
+            glkView.enableSetNeedsDisplay = false
+            glkView.bindDrawable()
+            drawFrame = CGRect(origin: CGPoint.zero, size: CGSize(width: glkView.drawableWidth, height: glkView.drawableHeight))
+        }
+    }
     
-    // MARK: OpenGL for gif preview
-    fileprivate var gifGLKView: GLKView!
-    fileprivate var gifCIContext: CIContext?
-    fileprivate var gifEaglContext: EAGLContext?
-    fileprivate var gifGLKViewPreviewViewBounds = CGRect()
+    /// OpenGL for live camera
+    private var liveCameraGLKView: CameraGLKView!
+    /// OpenGL for gif preview
+    private var gifGLKView: CameraGLKView!
     
     // MARK: State
     fileprivate var cameraFace: CameraFace = .Back
@@ -62,8 +84,8 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         }
         
         didSet {
-            liveCameraGLKView.removeFromSuperview()
-            gifGLKView.removeFromSuperview()
+            liveCameraGLKView.glkView.removeFromSuperview()
+            gifGLKView.glkView.removeFromSuperview()
             guard let cameraOutput = cameraOutput else {
                 print("Error: video preview or camera output is nil")
                 return
@@ -72,8 +94,8 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
                 print("Error: sample buffer view or gif output view is nil")
                 return
             }
-            sampleBufferOutput.addSubview(liveCameraGLKView)
-            gifOutputView.addSubview(gifGLKView)
+            sampleBufferOutput.addSubview(liveCameraGLKView.glkView)
+            gifOutputView.addSubview(gifGLKView.glkView)
         }
     }
     
@@ -83,6 +105,7 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         case configurationFailed
         case notAuthorized
     }
+    
     private var setupResult: SessionSetupResult = .success
     
     // MARK: Orientation
@@ -127,18 +150,20 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         let path = URL.pathWith(subpath: "/original")
         return URL(fileURLWithPath: path)
     }
-    func getMaxPixel(scale: Double) -> Int {
-        let longerSide = Double(max(frame.height, frame.width))
+    
+    func maxpixel(scale: Double) -> Int {
+        let longerSide = Double(max(captureSize.size().height, captureSize.size().width))
         return Int(longerSide / scale)
     }
+    
     // scale 3 is around 500KB
     // scale 2 is around 800KB ~ 1000KB
     // scale 2.1 is 900KB with text and drawing
     // scale 1 is around 3000K
     //let pixelSizeForMessage = getMaxPixel(scale: 2.1) // 350 on iPhone 7 plus, 317 on iPhone 6
     //let pixelSizeForThumbnail = getMaxPixel(scale: 3) // 245 on iPhone 7 plus, 222 on iphone 6
-    var messagePixelSize = Camera.Size.MessagePixelSize
-    var thumbnailPixelSize = Camera.Size.ThumbnailPixelSize
+    var messagePixelSize = Camera.pixelsize.message
+    var thumbnailPixelSize = Camera.pixelsize.thumbnail
     var shouldSaveFrame: Bool {
         return self.didOutputSampleBufferMethodCallCount % self.currentLiveGifPreset.frameCaptureFrequency == 0
     }
@@ -207,7 +232,7 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
                 pixelBufferCount = 0
             }
             var sourceImage: CIImage = CIImage(cvPixelBuffer: pixelBuffer)
-            sourceImage = sourceImage.adjustedExtentForGLKView()
+            sourceImage = sourceImage.adjustedExtentForGLKView(liveCameraGLKView.drawFrame.size)
             stillShot = sourceImage
             
             // filteredImage has the same address as sourceImage
@@ -216,36 +241,36 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
                 return
             }
             
-            liveCameraGLKView.bindDrawable()
+            liveCameraGLKView.glkView.bindDrawable()
             
             // Prepare CIContext with EAGLContext
-            if liveCameraEaglContext != EAGLContext.current() {
-                EAGLContext.setCurrent(liveCameraEaglContext)
+            if liveCameraGLKView.eaglContext != EAGLContext.current() {
+                EAGLContext.setCurrent(liveCameraGLKView.eaglContext)
             }
             setupOpenGL()
-            liveCameraCIContext?.draw(filteredImage, in: liveCameraGLKViewBounds, from: sourceImage.extent)
-            liveCameraGLKView.display()
+            liveCameraGLKView.ciContext.draw(filteredImage, in: liveCameraGLKView.drawFrame, from: sourceImage.extent)
+            liveCameraGLKView.glkView.display()
         }
         
         if isPostRecording {
-            if let stillShot = stillShot {
-                
-                DispatchQueue.main.async {
-                    let cvc = self.cameraOutput as? CameraViewController
-                    let vc = UIViewController()
-                    vc.view.backgroundColor = UIColor.red
-                    let image = UIImage(ciImage: stillShot)
-                    let imageView = UIImageView(image: image)
-                    imageView.frame = UIScreen.main.bounds
-                    
-                    print("image view: \(imageView)")
-                    print("image: \(image)")
-                    vc.view.addSubview(imageView)
-                    cvc?.present(vc, animated: true, completion: {
-                        print("view controller presented")
-                    })
-                }
-            }
+//            if let stillShot = stillShot {
+//                
+//                DispatchQueue.main.async {
+//                    let cvc = self.cameraOutput as? CameraViewController
+//                    let vc = UIViewController()
+//                    vc.view.backgroundColor = UIColor.red
+//                    let image = UIImage(ciImage: stillShot)
+//                    let imageView = UIImageView(image: image)
+//                    imageView.frame = UIScreen.main.bounds
+//                    
+//                    print("image view: \(imageView)")
+//                    print("image: \(image)")
+//                    vc.view.addSubview(imageView)
+//                    cvc?.present(vc, animated: true, completion: {
+//                        print("view controller presented")
+//                    })
+//                }
+//            }
             
             // stop
             if pixelBufferCount == pixelBufferCountAtSnapping + pixelBufferMaxCount {
@@ -290,55 +315,45 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         didOutputSampleBufferMethodCallCount += 1
 
     }
-    
+
     // MARK: - Initial setups
-    init(frame: CGRect) {
+    
+    override init() {
         super.init()
-        self.frame = frame
+        setup()
+    }
+        
+    deinit {
+        removeSessionObserver()
+    }
+    
+    private func setup() {
         setupSessionObserver()
         setupLiveCameraGLKView()
         setupGifGLKView()
         setupOpenGL()
         setupSession()
         setupAssetWriter(assetWriterID: .First)
-        setupAssetWriter(assetWriterID: .Second)
+        setupAssetWriter(assetWriterID: .Second)        
     }
-    
-    deinit {
-        removeSessionObserver()
-    }
-    
-    func setupLiveCameraGLKView() {
-        guard let liveCameraEaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
-            print("Error: eaglContext is nil")
+
+    private func setupLiveCameraGLKView() {
+        guard let eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
+            print("Error: failed to create EAGLContext in \(#function)")
             setupResult = .configurationFailed
             return
         }
-        self.liveCameraEaglContext = liveCameraEaglContext
-        liveCameraGLKView = GLKView(frame: frame, context: liveCameraEaglContext)
-        liveCameraGLKView.enableSetNeedsDisplay = false // disable normal UIView drawing cycle
-        liveCameraGLKView.bindDrawable()
-        liveCameraGLKViewBounds = CGRect.zero
-        liveCameraGLKViewBounds.size.width = CGFloat(liveCameraGLKView.drawableWidth)
-        liveCameraGLKViewBounds.size.height = CGFloat(liveCameraGLKView.drawableHeight)
-        liveCameraCIContext = CIContext(eaglContext: liveCameraEaglContext)
-        liveCameraGLKView.delegate = self
+
+        liveCameraGLKView = CameraGLKView(frame: CGRect(origin: CGPoint.zero, size: captureSize.size()), context: eaglContext)
     }
     
-    func setupGifGLKView() {
-        guard let gifEaglContext =  EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
+    private func setupGifGLKView() {
+        guard let eaglContext =  EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
             print("Error: failed to create EAGLContext in \(#function)")
+            setupResult = .configurationFailed
             return
         }
-        self.gifEaglContext = gifEaglContext
-        gifGLKView = GLKView(frame: frame, context: gifEaglContext)
-        gifGLKView.enableSetNeedsDisplay = false
-        gifGLKView.bindDrawable()
-        gifGLKViewPreviewViewBounds = CGRect.zero
-        gifGLKViewPreviewViewBounds.size.width = CGFloat(gifGLKView.drawableWidth)
-        gifGLKViewPreviewViewBounds.size.height = CGFloat(gifGLKView.drawableHeight)
-        gifCIContext = CIContext(eaglContext: gifEaglContext)
-        gifGLKView.delegate = self
+        gifGLKView = CameraGLKView(frame: CGRect(origin: CGPoint.zero, size: captureSize.size()), context: eaglContext)
     }
     
     /** Authorize camera usage. */
@@ -437,7 +452,6 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         sessionQueue.suspend()
         askUserCameraAccessAuthorization { (authorized: Bool) in
             if authorized {
-                print("camera access authorized")
                 self.setupResult = .success
                 self.sessionQueue.resume()
             } else {
@@ -463,11 +477,11 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
     }
     
     internal func tapToFocusAndExposure(touch: UITouch) {
-        let touchPoint = touch.location(in: liveCameraGLKView)
+        let touchPoint = touch.location(in: liveCameraGLKView.glkView)
         // https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
         // convert device point to image point in unit
-        let convertedX = touchPoint.y / frame.height
-        let convertedY = (frame.width - touchPoint.x) / frame.width
+        let convertedX = touchPoint.y / captureSize.size().height
+        let convertedY = (captureSize.size().width - touchPoint.x) / captureSize.size().width
         let convertedPoint = CGPoint(x: convertedX, y: convertedY)
         focus(with: .autoFocus, exposureMode: .autoExpose, at: convertedPoint)
         
@@ -1071,9 +1085,9 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
     // MARK: - Camera Controls
     internal func start() {
         session.startRunning()
-        if !session.isRunning {
-            print("Error: camera failed to run.")
-        }
+//        if !session.isRunning {
+//            print("Error: camera failed to run.")
+//        }
     }
     
     internal func stop() {
@@ -1115,6 +1129,7 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         
         var urls = [URL]()
         for image in filteredResizedUIImages {
+            let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: captureSize.size().width, height: captureSize.size().height))
             let renderedImage = image.render(items: renderItems, frame: frame)
             guard let cgImage = renderedImage.cgImage else {
                 print("Error: Could not get cgImage from rendered UIImage in \(#function)")
@@ -1240,7 +1255,7 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
     func showAnimatedImageView() {
         // make resized images from originals here
         var resizedTempURLs = [URL]()
-        let resizedMaxPixel = getMaxPixel(scale: 1)
+        let resizedMaxPixel = maxpixel(scale: 1)
         for url in originalURLs {
             if let resizedUrl = url.resize(maxSize: resizedMaxPixel, destinationURL: resizedUrlPath) {
                 resizedTempURLs.append(resizedUrl)
@@ -1268,6 +1283,63 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
         }
     }
     
+    func showGifWithGLKView() {
+        // make resized images from originals here
+        var resizedTempURLs = [URL]()
+        let resizedMaxPixel = maxpixel(scale: 1)
+        for url in originalURLs {
+            if let resizedUrl = url.resize(maxSize: resizedMaxPixel, destinationURL: resizedUrlPath) {
+                resizedTempURLs.append(resizedUrl)
+            } else {
+                print("Error: failed to get resized URL")
+            }
+        }
+        
+        resizedURLs = resizedTempURLs
+        
+        var resizedCIImages = [CIImage]()
+        for url in resizedTempURLs {
+            guard let sourceCIImage = url.cgImage?.ciImage else {
+                print("Error: cgImage is nil in \(#function)")
+                return
+            }
+            resizedCIImages.append(sourceCIImage)
+        }
+        
+        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async { [unowned self] in
+            self.gifGLKView.glkView.bindDrawable()
+    
+            if self.gifGLKView.eaglContext != EAGLContext.current() {
+                EAGLContext.setCurrent(self.gifGLKView.eaglContext)
+            }
+            
+            self.setupOpenGL()
+            while !self.session.isRunning {
+                if self.session.isRunning {
+                    break
+                }
+                
+                self.setupOpenGL()
+                for image in resizedCIImages {
+                    if self.session.isRunning {
+                        break
+                    }
+                    if let filter = self.currentFilter.filter {
+                        filter.setValue(image, forKey: kCIInputImageKey)
+                        if let outputImage = filter.outputImage {
+                            self.gifGLKView.ciContext.draw(outputImage, in: self.gifGLKView.drawFrame, from: image.extent)
+
+                        }
+                    } else {
+                        self.gifGLKView.ciContext.draw(image, in: self.gifGLKView.drawFrame, from: image.extent)
+                    }
+                    self.gifGLKView.glkView.display()
+                    usleep(useconds_t(self.currentLiveGifPreset.sleepDuration))
+                }
+            }
+        }
+    }
+    
     func showGifWithGLKView(with imageURLs: [URL]) {
         DispatchQueue.main.async {
             // make resized images from originals here
@@ -1283,16 +1355,18 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
             }
             ciImages.append(sourceCIImage)
         }
-        self.cameraOutput?.gifOutputView?.isHidden = false
-        if self.gifEaglContext != EAGLContext.current() {
-            EAGLContext.setCurrent(self.gifEaglContext)
-        }
+
+        cameraOutput?.gifOutputView?.isHidden = false
         
-        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async { [unowned self] in
-            self.gifGLKView.bindDrawable()
+        if gifGLKView.eaglContext != EAGLContext.current() {
+            EAGLContext.setCurrent(gifGLKView.eaglContext)
+        }
+        //DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async { [unowned self] in
+        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive).async { [unowned self] in
+            self.gifGLKView.glkView.bindDrawable()
             
-            if self.gifEaglContext != EAGLContext.current() {
-                EAGLContext.setCurrent(self.gifEaglContext)
+            if self.gifGLKView.eaglContext != EAGLContext.current() {
+                EAGLContext.setCurrent(self.gifGLKView.eaglContext)
             }
             
             self.setupOpenGL()
@@ -1309,13 +1383,13 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
                     if let filter = self.currentFilter.filter {
                         filter.setValue(image, forKey: kCIInputImageKey)
                         if let outputImage = filter.outputImage {
-                            self.gifCIContext?.draw(outputImage, in: self.gifGLKViewPreviewViewBounds, from: image.extent)
+                            self.gifGLKView.ciContext.draw(outputImage, in: self.gifGLKView.drawFrame, from: image.extent)
                         }
                     } else {
-                        self.gifCIContext?.draw(image, in: self.gifGLKViewPreviewViewBounds, from: image.extent)
+                        self.gifGLKView.ciContext.draw(image, in: self.gifGLKView.drawFrame, from: image.extent)
                     }
-                    
-                    self.gifGLKView.display()
+
+                    self.gifGLKView.glkView.display()
                     usleep(useconds_t(self.currentLiveGifPreset.sleepDuration))
                 }
             }
@@ -1336,6 +1410,7 @@ class SatoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
             }
         }
         
+        let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: captureSize.size().width, height: captureSize.size().height))
         let imageView = UIImageView(frame: frame)
         imageView.animationImages = filteredUIImages
         imageView.animationRepeatCount = 0
@@ -1376,7 +1451,7 @@ struct LiveGifPreset {
     var frameCaptureFrequency: Int {
         return Int(sampleBufferFPS) / gifFPS
     }
-    var sampleBufferFPS: Int32 = Int32(Camera.LiveGifPreset.SampleBufferFPS)
+    var sampleBufferFPS: Int32 = Int32(Camera.liveGifPreset.sampleBufferFPS)
     var liveGifFrameTotalCount: Int {
         return Int(gifDuration * Double(gifFPS))
     }
@@ -1393,8 +1468,8 @@ struct LiveGifPreset {
         self.gifDuration = gifDuration
     }
     init() {
-        self.gifFPS = Camera.LiveGifPreset.GifFPS
-        self.gifDuration = TimeInterval(Camera.LiveGifPreset.GifDuration)
+        self.gifFPS = Camera.liveGifPreset.gifFPS
+        self.gifDuration = TimeInterval(Camera.liveGifPreset.gifDuration)
     }
 }
 
@@ -1578,9 +1653,9 @@ enum CGImagePropertyOrientation: Int {
 
 extension CIImage {
     /** Crop center square from rectangle shaped CIImage*/
-    func adjustedExtentForGLKView() -> CIImage {
+    func adjustedExtentForGLKView(_ size: CGSize) -> CIImage {
         let sourceHeight = self.extent.height
-        let newHeight = self.extent.width
+        let newHeight = size.height
         let gap = sourceHeight - newHeight
         let originY = gap / 2
         let extent = CGRect(origin: CGPoint(x: self.extent.origin.x, y: originY), size: CGSize(width: self.extent.width, height: self.extent.width))
