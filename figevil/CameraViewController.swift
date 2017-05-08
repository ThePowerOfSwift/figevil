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
        //view.bringSubview(toFront: sampleBufferView!)
        interfaceView.contentView.bringSubview(toFront: sampleBufferView!)
        addSwipeRecognizers(targetView: sampleBufferView!)
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
        if let action = barButtonMap[sender] as? interfaceAction {
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
        shareButton.isEnabled = false
        
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
        let layout = StraightCollectionViewLayout()
        menuBubbleCVC = BubbleMenuCollectionViewController(collectionViewLayout: layout)
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
        if effects.count > 0 {
            effects[selectedEffectIndex].didSelectPrimaryMenuItem?(indexPath.row)
            
        }
    }
    
    // func scroll
    // effects[0].didSelectPrimaryMenuItem(filterIndex)
    
    func addSwipeRecognizers(targetView: UIView) {
        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(filterSwiped(sender:)))
        rightSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.right
        targetView.addGestureRecognizer(rightSwipeGestureRecognizer)
        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(filterSwiped(sender:)))
        leftSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.left
        targetView.addGestureRecognizer(leftSwipeGestureRecognizer)
    }
    
    func filterSwiped(sender: UISwipeGestureRecognizer) {
        if sender.direction == UISwipeGestureRecognizerDirection.right {
            print("swiped right")
            if satoCamera.currentFilterIndex == Filter.shared.list.count - 1 {
                satoCamera.currentFilterIndex = 0
            } else {
                satoCamera.currentFilterIndex += 1
            }
            satoCamera.didSelectFilter(nil, index: satoCamera.currentFilterIndex)
            let indexPath = IndexPath(row: satoCamera.currentFilterIndex, section: 0)
            //menuBubbleCVC?.collectionView?.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.left, animated: true)
            menuBubbleCVC?.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.left)
            
//            if currentFilterIndex == Filter.shared.list.count - 1 {
//                currentFilterIndex = 0
//            } else {
//                currentFilterIndex += 1
//            }
//            didSelectFilter(nil, index: currentFilterIndex)
            
        } else {
            print("swiped left")
            if satoCamera.currentFilterIndex == 0 {
                satoCamera.currentFilterIndex = Filter.shared.list.count - 1
            } else {
                satoCamera.currentFilterIndex -= 1
            }
            satoCamera.didSelectFilter(nil, index: satoCamera.currentFilterIndex)
            let indexPath = IndexPath(row: satoCamera.currentFilterIndex, section: 0)
//            menuBubbleCVC?.collectionView?.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.left, animated: true)
            menuBubbleCVC?.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.left)
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
    
    // TODO:
    func tappedFlashView(_ sender: UITapGestureRecognizer) {
        let touches = sender.value(forKey: "touches") as! [UITouch]
        satoCamera.tapToFocusAndExposure(touch: touches.first!)
    }

    func reset() {
        satoCamera.reset()
        interfaceView.reset()
        effects.forEach({ $0.reset() })
    }
    
    func save() {
        // render animation into movie
        guard let originalMovURL = satoCamera.resultVideoURL else {
            print("Error: No recorded video to save")
            reset()
            return
        }
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("result.m4v")
        
        render(originalMovURL, outputURL: outputURL) {
            DispatchQueue.main.async {
                self.satoCamera.generateThumbnailImagesFrom(videoURL: outputURL, completion: { (urls: [URL]) in
                    // resize for thumbnail
                    var thumbnailTempURLs = [URL]()
                    for url in urls {
                        let thumbnailTempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
                        if url.resize(maxSize: Camera.pixelsize.thumbnail, destinationURL: thumbnailTempURL) {
                            thumbnailTempURLs.append(thumbnailTempURL)
                        } else {
                            print("Error: url is resized.")
                        }
                    }
                    
                    let path = UUID().uuidString
                    let gifFileURL = URL.messageURL(path: path)
                    let gifThumbnailURL = URL.thumbnailURL(path: path)
                    
                    if thumbnailTempURLs.makeGifFile(frameDelay: 0.5, destinationURL: gifThumbnailURL) {
                        print("thumbnail is saved to URL.thumbnail directory. size: \(String(describing: gifThumbnailURL.filesize))")
                    } else {
                        print("thumbnail could NOT saved to URL.thumbnail directory")
                    }
                    
                    // TODO: Save to PHLibrary
                    
                    if urls.makeGifFile(frameDelay: 0.5, destinationURL: gifFileURL) {
                        print("urls.makeGifFile")
                        PHPhotoLibrary.requestAuthorization { (status) -> Void in
                            switch (status) {
                            case .authorized:
                                PHPhotoLibrary.shared().performChanges({
                                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: gifFileURL)
                                }, completionHandler: { (saved: Bool, error: Error?) in
                                    if saved {
                                    } else {
                                        print("Error: did not save gif")
                                    }
                                })
                            case .denied:
                                print("Error: User denied")
                            default:
                                print("Error: Restricted")
                            }
                        }
                    } else {
                        print("Error: Faild to make gif file.")
                    }
                })
                // Reset the camera
                self.reset()
            }
        }
    }
    

    
    // TODO:
    /// Saves gif and open share sheet
    func share() {
        /*
        // Save to location
        var savedURL: URL =
        // Share
        do {
            let gifData = try Data(contentsOf: savedUrl)
            let activityItems: [Any] = [gifData as Any]
            let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            self.present(activityViewController, animated: true, completion: nil)
        } catch {
            print("Error: cannot get data of GIF \(savedUrl.path)")
        }*/
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
    
    func render(_ videoURL: URL, outputURL: URL, completion: (()->())?) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.m4v")
        applyFilter(satoCamera.currentFilter.filter, toVideo: videoURL, outputURL: tempURL) {
            self.overlayEffectsToVideo(tempURL, outputURL: outputURL) {
                completion?()
            }
        }
    }
    
    /// Export video composition
    func export(_ asset: AVAsset, with videoComposition:AVVideoComposition, to: URL, completion: (()->())?) {
        
        // TODO: if satoCamera.isRunning
        satoCamera.stop()  // Without this line a Mach error is thrown with multi thread conflict w/ camera access
        
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
            _ = group.wait(timeout: DispatchTime.init(uptimeNanoseconds: 500 * NSEC_PER_SEC))
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
                interfaceView.primaryMenuViewBottomConstraint.constant = height

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
            
            interfaceView.primaryMenuViewBottomConstraint.constant = 0

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
