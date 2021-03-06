//
//  NewCameraViewController.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/19/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Photos
import MobileCoreServices

class CameraViewController: UIViewController, SatoCameraOutput, BubbleMenuCollectionViewControllerDatasource, BubbleMenuCollectionViewControllerDelegate {
    
    /** Model */
    var satoCamera: SatoCamera = SatoCamera.shared
    var aspectRatio = Camera.screen.square {
        didSet {
            if oldValue != aspectRatio {
                updateAspectRatio()
            }
        }
    }
    
    var interfaceView: CameraInterfaceView {
        return view as! CameraInterfaceView
    }
    
    var isBusy: Bool = false {
        didSet {
            interfaceView.isUserInteractionEnabled = !isBusy
        }
    }
    
    // MARK: SatoCameraOutput
    // TODO: roll views into one
    // Must always be behind all other views
    var sampleBufferView: UIView? = UIView()
    // Must always be on top of sampleBuffer
    var gifOutputView: UIView? = UIView()

    
    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if !debugCameraOff {
            setupSatoCamera()
        }
        setupInterfaceView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.satoCamera.start()
        
        setupKeyboardObserver()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        satoCamera.stop()
        removeKeyboardObserver()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("received memory warning")
    }
    
    deinit {
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: SatoCamera
    
    func setupSatoCamera() {
        for view in [sampleBufferView!, gifOutputView!] {
            view.frame = interfaceView.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            interfaceView.contentView.addSubview(view)
        }
        satoCamera.cameraOutput = self
    }
    
    // MARK: InterfaceView

    enum interfaceAction {
        case capture, flash, load, reset, share, selfie, save, aspectRatio
    }
    
    func tappedInterface(_ sender: UIBarButtonItem) {
        if let action = barButtonMap[sender] as? interfaceAction, !isBusy {
            switch action {
            case .capture:
                satoCamera.snapLiveGif()
                interfaceView.toggleInterface()
            case .flash:
                interfaceView.update(with: toggleTorch())
            case .load:
                // TODO:
                break
            case .reset:
                reset()
            case .share:
                share()
            case .selfie:
                toggleSelfie()
            case .save:
                save()
            case .aspectRatio:
                toggleAspectRatio()
            }
        }
    }
    
    func setupInterfaceView() {
        setupBarButton()
        
        setupEffects()
        // Setup collection views for menu and options
        setupMenuBubbles()
        setupFilterSwipe()
        setupBubbleMenuClipToBounds()
    }
    
    func setupFilterSwipe() {
        interfaceView.contentView.bringSubview(toFront: sampleBufferView!)
        addSwipeRecognizers(to: sampleBufferView!)
    }
    
    var barButtonMap: [UIBarButtonItem: AnyObject] = [:]
    func setupBarButton() {
        // Interface status
        let liveBarButtonItem = UIBarButtonItem(title: "LIVE", style: .plain, target: nil, action: nil)
        let yellow = UIColor(displayP3Red: 248/255, green: 211/255, blue: 76/255, alpha: 1.0)
        liveBarButtonItem.setTitleTextAttributes([NSForegroundColorAttributeName: yellow], for: .normal)
        liveBarButtonItem.isEnabled = false

        // Camera actions
        
        let downloadButton = UIBarButtonItem(image: #imageLiteral(resourceName: "downloads"), style: .plain, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[downloadButton] = interfaceAction.load as AnyObject
        // TODO: Implement download
        downloadButton.isEnabled = false
        
        let flashButton = UIBarButtonItem(image: #imageLiteral(resourceName: "flash"), style: .plain, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[flashButton] = interfaceAction.flash as AnyObject
        
        let resetButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[resetButton] = interfaceAction.reset as AnyObject
        
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[shareButton] = interfaceAction.share as AnyObject
        
        let circleImage = #imageLiteral(resourceName: "circle")
        let circleBarButton = UIBarButtonItem(image: circleImage, style: .plain, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[circleBarButton] = interfaceAction.capture as AnyObject
        // Set toolbar height when circle visible
        interfaceView.bottomToolbarHeight = circleImage.size.height + 10
        
        let selfieBarButton = UIBarButtonItem(image: #imageLiteral(resourceName: "selfie"), style: .plain, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[selfieBarButton] = interfaceAction.selfie as AnyObject
        
        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[saveButton] = interfaceAction.save as AnyObject

        let aspectRatioButton = UIBarButtonItem(image: #imageLiteral(resourceName: "fullscreen"), style: .plain, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[aspectRatioButton] = interfaceAction.aspectRatio as AnyObject

        // Camera Effects
        
        let filterEffectButton = UIBarButtonItem(image: #imageLiteral(resourceName: "filter"), style: .plain, target: self, action: #selector(tappedEffect(_:)))
        filterEffectButton.tag = 0
        barButtonMap[filterEffectButton] = 0 as AnyObject

        let stickerEffectButton = UIBarButtonItem(image: #imageLiteral(resourceName: "sticker"), style: .plain, target: self, action: #selector(tappedEffect(_:)))
        stickerEffectButton.tag = 1
        barButtonMap[stickerEffectButton] = 1 as AnyObject
        
        let textEffectButton = UIBarButtonItem(image: #imageLiteral(resourceName: "text.png"), style: .plain, target: self, action: #selector(tappedEffect(_:)))
        textEffectButton.tag = 2
        barButtonMap[textEffectButton] = 2 as AnyObject
        
        let drawEffectButton = UIBarButtonItem(image: #imageLiteral(resourceName: "draw"), style: .plain, target: self, action: #selector(tappedEffect(_:)))
        drawEffectButton.tag = 3
        barButtonMap[drawEffectButton] = 3 as AnyObject
        
        // Set toolbar items
        
        interfaceView.captureTopItems = [downloadButton,
                                         UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         liveBarButtonItem,
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         aspectRatioButton,
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         flashButton]
        interfaceView.previewTopItems = [resetButton,
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         shareButton]
        interfaceView.captureBottomItems = [filterEffectButton,
                                            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                            circleBarButton,
                                            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                            selfieBarButton]
        interfaceView.previewBottomItems = [filterEffectButton,
                                            stickerEffectButton,
                                            textEffectButton,
                                            drawEffectButton,
                                            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                            saveButton]
        
        // Update the interface
        interfaceView.updateInterface()
    }
    
    var menuBubbleCVC: BubbleMenuCollectionViewController?
    func setupMenuBubbles() {
//        let layout = StraightCollectionViewLayout()
//        menuBubbleCVC = BubbleMenuCollectionViewController(collectionViewLayout: layout)
        let circularLayout = CircularCollectionViewLayout()
        menuBubbleCVC = BubbleMenuCollectionViewController(collectionViewLayout: circularLayout)
        menuBubbleCVC!.datasource = self
        menuBubbleCVC!.delegate = self
        
        addChildViewController(menuBubbleCVC!)
        interfaceView.primaryMenuView.addSubview(menuBubbleCVC!.view)
        menuBubbleCVC!.view.frame = interfaceView.primaryMenuView.bounds
        
        menuBubbleCVC!.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menuBubbleCVC!.didMove(toParentViewController: self)
    }
    
    // MARK: BubbleMenuCollectionViewControllerDatasource
    
    func bubbleMenuContent(for bubbleMenuCollectionViewController: BubbleMenuCollectionViewController) -> [BubbleMenuCollectionViewCellContent] {
        return effects.count > 0 ? effects[selectedEffectIndex].primaryMenu ?? [] : []
    }
    
    // MARK: BubbleMenuCollectionViewControllerDelegate
    func bubbleMenuCollectionViewController(_ bubbleMenuCollectionViewController: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath) {
        unclipBubbleCollectionView()
        if effects.count > 0 {
            effects[selectedEffectIndex].didSelectPrimaryMenuItem?(indexPath.row)
        }
    }
    
    func bubbleMenuCollectionViewController(_ bubbleMenuCollectionViewController: BubbleMenuCollectionViewController, didScroll: Bool) {
        unclipBubbleCollectionView()
    }
    
    // MARK: Clipping collection view animation
    var timer: Timer!
    var isClipped: Bool = true
    var primaryMenuClipViewWidthConstraintOriginalValue: CGFloat?
    var primaryMenuClipViewBottomConstraintOriginalValue: CGFloat?
    // https://stackoverflow.com/questions/31690634/how-to-reset-nstimer-swift-code
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(clipBubbleCollectionView), userInfo: "timer", repeats: true)
    }
    
    func resetTimer() {
        timer.invalidate()
        startTimer()
    }
    
    func clipBubbleCollectionView() {
        if !isClipped {
            if let originalWidth = primaryMenuClipViewWidthConstraintOriginalValue, let originalBottom = primaryMenuClipViewBottomConstraintOriginalValue {
                UIView.animate(withDuration: 0.3, animations: {
                    self.interfaceView.primaryMenuClipViewWidthConstraint.constant = originalWidth
                    self.interfaceView.primaryMenuClipViewBottomConstraint.constant = originalBottom
                    self.view.layoutIfNeeded()
                })
            }
            isClipped = true
        }
    }
    
    func unclipBubbleCollectionView() {
        if isClipped {
            UIView.animate(withDuration: 0.3, animations: {
                self.interfaceView.primaryMenuClipViewWidthConstraint.constant = self.view.frame.width
                if let originalBottom = self.primaryMenuClipViewBottomConstraintOriginalValue {
                    self.interfaceView.primaryMenuClipViewBottomConstraint.constant = originalBottom + 50
                }
                self.view.layoutIfNeeded()
                self.resetTimer()
            })
            isClipped = false
        }
    }
    
    func setupBubbleMenuClipToBounds() {
        interfaceView.primaryMenuClipView.clipsToBounds = true
        // store original value of constraint
        primaryMenuClipViewWidthConstraintOriginalValue = interfaceView.primaryMenuClipViewWidthConstraint.constant
        primaryMenuClipViewBottomConstraintOriginalValue = interfaceView.primaryMenuClipViewBottomConstraint.constant
        startTimer()
    }
    
    /** Add swipe recognizer for right and left to a view. */
    func addSwipeRecognizers(to targetView: UIView) {
        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(filterSwiped(sender:)))
        rightSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.right
        targetView.addGestureRecognizer(rightSwipeGestureRecognizer)
        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(filterSwiped(sender:)))
        leftSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.left
        targetView.addGestureRecognizer(leftSwipeGestureRecognizer)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first?.view == satoCamera.liveCameraGLKView.glkView {
            satoCamera.tapToFocusAndExposure(touch: touches.first!)
        }
    }
    
    /** Detect swipe diretion and change filter. */
    func filterSwiped(sender: UISwipeGestureRecognizer) {
        if sender.direction == UISwipeGestureRecognizerDirection.left {
            if satoCamera.currentFilterIndex == Filter.shared.list.count - 1 {
                //satoCamera.currentFilterIndex = 0
            } else {
                satoCamera.currentFilterIndex += 1
            }
            satoCamera.didSelectFilter(nil, index: satoCamera.currentFilterIndex)
            let indexPath = IndexPath(row: satoCamera.currentFilterIndex, section: 0)
            menuBubbleCVC?.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.left)
            unclipBubbleCollectionView()
        } else {
            if satoCamera.currentFilterIndex == 0 {
                //satoCamera.currentFilterIndex = Filter.shared.list.count - 1
            } else {
                satoCamera.currentFilterIndex -= 1
            }

            satoCamera.didSelectFilter(nil, index: satoCamera.currentFilterIndex)
            let indexPath = IndexPath(row: satoCamera.currentFilterIndex, section: 0)
            menuBubbleCVC?.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.right)
            unclipBubbleCollectionView()
        }
    }
    
    // MARK: Effects
    
    /// Tracks which effect tool is currently selected and activates newly selected effect
    var selectedEffectIndex = 0 {
        didSet {
            if effects.count > 0 {
                // Change effect
                effects[selectedEffectIndex].isSelected?()
                // Bring to front
                if let effect = effects[selectedEffectIndex] as? UIView {
                    interfaceView.contentView.bringSubview(toFront: effect)
                }
                // Load menu
                menuBubbleCVC?.collectionView?.reloadData()
            }
        }
    }

    var effects: [CameraEffect] = [FilterImageEffect(),
                                AnimationEffectView(),
                                TextImageEffectView(),
                                DrawImageEffectView()]
    
    func setupEffects() {
        // Add each effect
        for effect in effects {
            if let effect = effect as? UIView {
                effect.frame = interfaceView.contentView.bounds
                effect.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                interfaceView.contentView.addSubview(effect)
            }
            if let effect = effect as? FilterImageEffect {
                effect.delegate = satoCamera
            }
        }
        
        if let animationEffectView = effects[1] as? AnimationEffectView {
            interfaceView.contentView.bringSubview(toFront: animationEffectView)
        }
    }
    
    func tappedEffect(_ sender: UIBarButtonItem) {
        let index = sender.tag
        if selectedEffectIndex != index {
            selectedEffectIndex = index
        }
    }
    
    // MARK: Camera controls
    
    func tappedFlashView(_ sender: UITapGestureRecognizer) {
        let touches = sender.value(forKey: "touches") as! [UITouch]
        satoCamera.tapToFocusAndExposure(touch: touches.first!)
    }

    func reset() {
        satoCamera.reset()
        interfaceView.reset()
        effects.forEach({ $0.reset() })
        isBusy = false
    }
    
    func save() {
        startRender(options: [.message, .thumbnail])
    }
    
    func saveToPHPhotoLibrary(_ url: URL) {
        PHPhotoLibrary.requestAuthorization { (status) -> Void in
            switch (status) {
            case .authorized:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }, completionHandler: { (saved: Bool, error: Error?) in
                    if saved {
                    } else {
                        print("Error: did not save to PHPhotoLibrary \(error?.localizedDescription ?? "")")
                    }
                })
            case .denied:
                print("Error: User denied")
            default:
                print("Error: Restricted")
            }
        }
    }
    
    /// Saves gif and open share sheet
    func share() {
        startRender(options: [.message, .share]) { (output) in
            
            // Share
            do {
                let gifData = try Data(contentsOf: output.first!)
                let activityItems: [Any] = [gifData as Any]
                let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                self.present(activityViewController, animated: true, completion: nil)
            } catch {
                print("Error: cannot get data of GIF \(output.first!.path)")
            }
        }
    }

    func toggleSelfie() {
        satoCamera.toggleCamera()
    }
    
    func toggleTorch() -> String {
        return satoCamera.toggleTorch()
    }
    
    func toggleAspectRatio() {
        aspectRatio.toggle()
    }

    // Force camera and interface to update content (capture / output) aspect ratio
    func updateAspectRatio() {
        // Update UI and camera
        satoCamera.captureSize = aspectRatio
        interfaceView.captureSize = aspectRatio
        
        // Update bar button image
        if let aspectBarButton = barButtonMap.filter({ ($0.value as? interfaceAction) == interfaceAction.aspectRatio }).first?.key {
            aspectBarButton.image = aspectRatio == .fullscreen ? #imageLiteral(resourceName: "squarescreen") : #imageLiteral(resourceName: "fullscreen")
        }
    }

    // MARK: Rendering
    
    enum renderOptions {
        case share
        case message
        case thumbnail
        
        func maxPixelSize() -> Int? {
            switch self {
            case .message:
                return Camera.pixelsize.message
            case .thumbnail:
                return Camera.pixelsize.thumbnail
            default:
                return nil
            }
        }
        
        func generateNewURL(path: String) -> URL {
            switch self {
            case .message:
                return URL.messageURL(path: path)
            case .thumbnail:
                return URL.thumbnailURL(path: path)
            case .share:
                return URL(fileURLWithPath: NSTemporaryDirectory().appending(path))
            }
        }
    }
    
    func startRender(options: [renderOptions], completion:((_ output: [URL])->())? = nil) {
        isBusy = true
        
        // render animation into movie
        guard let originalMovURL = satoCamera.resultVideoURL else {
            print("Error: No recorded video to save")
            reset()
            return
        }
        
        // Decompile options
        let sizeOptions = options.filter { $0 != .share }
        let maxPixelSize: [Int] = sizeOptions.flatMap { $0.maxPixelSize() }
        
        renderGIF(originalMovURL,
                  outputURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Autokey + FileExtension.movie)) { (videoURL) in
                    DispatchQueue.main.async {
                        
                        self.satoCamera.getImagesFrom(videoURL: videoURL, maxPixelSize: maxPixelSize, completion: { (urls: [URL]) in
                            
                            var outputURL: [URL] = []
                            let path = Autokey
                            sizeOptions.forEach { (sizeOption) in
                                let gifImageURL = urls.map { $0.maxpixelURL(sizeOption.maxPixelSize()!) }
                                let destinationURL = sizeOption.generateNewURL(path: path)
                                outputURL.append(destinationURL)
                                
                                if gifImageURL.makeGifFile(frameDelay: 0.5, destinationURL: destinationURL) {
                                    print("Gif saved with size: \(String(describing: destinationURL.filesize))")
                                } else {
                                    print("Error: Failed to create Message gif ")
                                }
                            }
                            
                            completion?(outputURL)
                            
                            // Reset the camera
                            DispatchQueue.main.async {
                                self.reset()
                            }
                        })
                    }
        }
    }

    func renderGIF(_ videoURL: URL, outputURL: URL, completion: ((_ videoURL: URL)->())?) {
        satoCamera.stop()  // Without this line a Mach error is thrown with multi thread conflict w/ camera access

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Autokey + FileExtension.movie)
        applyFilter(satoCamera.currentFilter.filter, toVideo: videoURL, outputURL: tempURL) {
            self.overlayEffectsToVideo(tempURL, outputURL: outputURL) {
                completion?(outputURL)
            }
        }
    }
    
    /// Export video composition
    func export(_ asset: AVAsset, with videoComposition:AVVideoComposition, to: URL, completion: (()->())?) {
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error: failed to initialize exporter to render filters")
            return
        }
        
        exporter.videoComposition = videoComposition
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        try? FileManager.default.removeItem(at: to)
        exporter.outputURL = to
        
        let group = DispatchGroup()
        group.enter()
        exporter.exportAsynchronously {
            group.leave()
            if let errorMessage = exporter.error?.localizedDescription {
                print("AVExport Error: \(errorMessage)")
            }
            completion?()
        }
        
        // Progress tracking
        var lastProgress: Float = 0
        while exporter.status == .exporting || exporter.status == .waiting {
            let currentProgress = exporter.progress * 100
            if currentProgress != lastProgress {
                print("session progress: \(currentProgress)")
                lastProgress = currentProgress
            }
            _ = group.wait(timeout: DispatchTime.init(uptimeNanoseconds: NSEC_PER_SEC / 2))
        }
    }
    
    func applyFilter(_ filter: CIFilter?, toVideo url: URL, outputURL: URL, completion: (()->())?) {
        let urlAsset = AVURLAsset(url: url)

        // Setup video composition to overlay animations and export
        let videoComposition = AVMutableVideoComposition(asset: urlAsset) { (request) in
            // Clamp to avoid blurring transparent pixels at the image edges
            
            var outputImage = request.sourceImage
            if let filter = filter {
                filter.setValue(request.sourceImage, forKey: kCIInputImageKey)
                if let image = filter.outputImage {
                    outputImage = image
                }
            }
            
            // Provide the filter output to the composition
            request.finish(with: outputImage, context: nil)
        }

        // Export video with filter
        export(urlAsset, with: videoComposition, to: outputURL, completion: completion)
    }
    
    func overlayEffectsToVideo(_ url: URL, outputURL: URL, completion: (()->())?) {
        // Accumulate overlay views to apply to video
        let animationEffectView = self.effects[1] as! AnimationEffectView
        let textEffectView = self.effects[2] as! TextImageEffectView
        let drawEffectView = self.effects[3] as! DrawImageEffectView
        let views: [UIView] = [animationEffectView.animationView, textEffectView.textView, drawEffectView.drawView]
        
        // Prep to overlay effects
        let urlAsset = AVURLAsset(url: url)
        let videoComposition = AVMutableVideoComposition(propertiesOf: urlAsset)
        let renderRect = CGRect(origin: CGPoint.zero, size: videoComposition.renderSize)
        // Sizes the animation and video layers- must be the same aspect ratio as AVAsset
        let animationLayerFrame = views.first!.frame
        
        // Make animation layer to superimpose on video
        let animationLayer = CALayer()
        animationLayer.frame = animationLayerFrame
        if animationLayer.contentsAreFlipped() {
            animationLayer.isGeometryFlipped = true
        }
        
        // Set video layer as "backing" layer (to be overlaid on)
        let videoLayer = CALayer()
        videoLayer.frame = animationLayerFrame
        animationLayer.addSublayer(videoLayer)
        
        // Make a sublayer for each animation
        for overlayView in views {
            animationLayer.addSublayer(overlayView.layer)
        }
        
        // Scale entire animation layer to fit the video
        // Calculate scale for mapping between onscreen and physical video
        let scaleX = renderRect.size.width / animationLayerFrame.width
        let scaleY = renderRect.size.height / animationLayerFrame.height
        animationLayer.setAffineTransform(CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Reposition the animation layer to overlay correctly over video
        animationLayer.frame.origin = CGPoint(x: 0, y: 0)
        
        // Apply animation to video composition
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: animationLayer)
        
        export(urlAsset, with: videoComposition, to: outputURL, completion: completion)
    }

    // MARK: SatoCameraOutput
    
    func didLiveGifStop() {
        print("live gif stopped")
    }
    
    // MARK: Keyboard
    
    func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }
    
    func removeKeyboardObserver() {
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
    }
    
    /** Keyboard appearance notification.  Pushes content (option menu) up to keyboard top floating */
    func keyboardWillShow(notification: NSNotification) {
        
        // See if menu should be pushed with keyboard
        if let _ = effects[selectedEffectIndex].showsPrimaryMenuOnKeyboard {
            // Get keyboard animation information
            guard let keyboardFrame = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect else {
                print("Error: Cannot retrieve Keyboard frame from keyboard notification")
                return
            }
            guard let animationTime = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double else {
                print("Error: Cannot retrieve animation duration from keyboard notification")
                return
            }

            if interfaceView.primaryMenuView.frame.minY < keyboardFrame.maxY {
                let height = keyboardFrame.height - interfaceView.bottomToolbar.frame.height
                interfaceView.primaryMenuClipViewBottomConstraint.constant = height

                UIView.animate(withDuration: animationTime, animations: {
                    self.view.layoutIfNeeded()
                })
            }
        }
    }
    
    /** Keyboard appearance notification.  Pushes content (option menu) back to original position when no keyboard is shown */
    func keyboardWillHide(notification: NSNotification) {
        
        // See if menu should be pushed with keyboard
        if let _ = effects[selectedEffectIndex].showsPrimaryMenuOnKeyboard {
            // Get keyboard animation information
            guard let animationTime = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double else {
                print("Error: Cannot retrienve animation duration from keyboard notification")
                return
            }
            
            interfaceView.primaryMenuClipViewBottomConstraint.constant = 0

            UIView.animate(withDuration: animationTime, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
}

@objc protocol CameraEffect {
    /// Tells the receiver it was selected
    @objc optional func isSelected()
    /// Reset the reciever to initial state
    func reset()

    /// Contents of the effect's configuration menu
    @objc optional var primaryMenu: [BubbleMenuCollectionViewCellContent] { get }
    /// Flag to show menu content at the top of keyboard
    @objc optional var showsPrimaryMenuOnKeyboard: Bool { get }
    /// Tells the reciever that a menu item was selected
    @objc optional func didSelectPrimaryMenuItem(_ atIndex: Int)
}
