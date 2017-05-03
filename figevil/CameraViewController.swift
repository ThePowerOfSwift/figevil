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
        case capture, flash, load, cancel, share, selfie, save
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
            case .cancel:
                cancel()
            case .share:
                share()
            case .selfie:
                toggleSelfie()
            case .save:
                save()
            }
        }
    }
    
    func setupInterfaceView() {
        setupBarButton()
        
        setupEffects()
        // Setup collection views for menu and options
        setupMenuBubbles()
        
        // Setup content frame
        //interfaceView.contentViewAspectConstraint.constant =
        let topContentHeight = interfaceView.topToolbar.frame.height + interfaceView.contentView.frame.height
        let bottomBackgroundHeight = view.frame.height - topContentHeight
        interfaceView.bottomBackgroundViewHeightConstraint.constant = bottomBackgroundHeight
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
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[cancelButton] = interfaceAction.cancel as AnyObject
        
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(tappedInterface(_:)))
        barButtonMap[shareButton] = interfaceAction.share as AnyObject
        // TODO:
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
        
        interfaceView.captureTopItems = [flashButton,
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         liveBarButtonItem,
                                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                                         downloadButton]
        interfaceView.previewTopItems = [cancelButton,
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

    func cancel() {
        satoCamera.reset()
        interfaceView.reset()
    }
    
    func save() {
        satoCamera.save(renderItems: nil) { (success, savedURLs, filesize) in
            // render animation into movie
            let originalMovURL = savedURLs?.video
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("result.m4v")
            
            self.render(originalMovURL!, outputURL: outputURL) {
                DispatchQueue.main.async {
                    self.satoCamera.generateThumbnailImagesFrom(videoURL: outputURL, completion: { (urls: [URL]) in
                        let gifFileURL = URL.messageURL(path: UUID().uuidString)
                        if urls.makeGifFile(frameDelay: 0.5, destinationURL: gifFileURL) {
                            PHPhotoLibrary.requestAuthorization
                                { (status) -> Void in
                                    switch (status)
                                    {
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
                }
            }
        }
        cancel()
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
    
    // MARK: Rendering
    
    func render(_ videoURL: URL, outputURL: URL, completion: (()->())?) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.m4v")
        if let filter = satoCamera.currentFilter.filter {
            applyFilter(filter, toVideo: videoURL, outputURL: tempURL) {
                self.overlayEffectsToVideo(tempURL, outputURL: outputURL) {
                    completion?()
                }
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
    
    func applyFilter(_ filter: CIFilter, toVideo url: URL, outputURL: URL, completion: (()->())?) {
        let urlAsset = AVURLAsset(url: url)

        // Setup video composition to overlay animations and export
        let videoComposition = AVMutableVideoComposition(asset: urlAsset) { (request) in
            // Clamp to avoid blurring transparent pixels at the image edges
            filter.setValue(request.sourceImage, forKey: kCIInputImageKey)
            let output = filter.outputImage!
            
            // Provide the filter output to the composition
            request.finish(with: output, context: nil)
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
