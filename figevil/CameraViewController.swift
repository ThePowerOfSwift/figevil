//
//  NewCameraViewController.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/19/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, SatoCameraOutput, BubbleMenuCollectionViewControllerDatasource, BubbleMenuCollectionViewControllerDelegate {
    
    // MARK: Snap Testing
    // TODO: temp var for effect option bottom constraint
    var lastconstant: CGFloat = 0

    func setupTest() {
        print("setup")
    }
    
    @IBOutlet var snapButton: UIButton!
    
    func setupSnapButton() {
        snapButton.addTarget(self, action: #selector(snapLiveGif(_:)), for: UIControlEvents.touchUpInside)
        
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(record(_:)))
        snapButton.addGestureRecognizer(longpress)
    }
    
    /** Snap live gif. */
    func snapLiveGif(_ sender: UIControlEvents) {
        satoCamera.snapLiveGif()
    }
    
    func record(_ sender: UILongPressGestureRecognizer) {
        //print("record")
        
        if sender.state == UIGestureRecognizerState.began {
            print("begin")
            satoCamera.startRecordingGif()
        } else if sender.state == UIGestureRecognizerState.ended {
            print("end")
            satoCamera.stopRecordingGif()
        }
    }
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBAction func tappedCancel(_ sender: Any) {
        cancel()
    }
    
    @IBOutlet weak var saveButton: UIButton!
    @IBAction func tappedSave(_ sender: Any) {
        save()
    }
    
    @IBOutlet weak var selfieButton: UIButton!
    @IBAction func tappedSelfie(_ sender: Any) {
        toggleSelfie()
    }
    
    @IBOutlet weak var flashButton: UIButton!
    @IBAction func tappedFlash(_ sender: Any) {
        toggleTorch()
    }

    /** Model */
    var satoCamera: SatoCamera!

    @IBOutlet var sampleBufferContainerView: UIView!
    @IBOutlet var outputImageContainerView: UIView!
    
    // MARK: SatoCameraOutput
    // Must always be behind all other views
    var sampleBufferView: UIView? = UIView()
    // Must always be on top of sampleBuffer
    var outputImageView: UIImageView? = UIImageView()
    
    var cameraAccessAuthorizationStatus: Bool = false

    /**
     View that holds all control views and the active effect tool; always floating.
     When an effect is active, the effect is moved to be above flashView (under control containers)
     */
    @IBOutlet var controlView: UIView!
    /** View that sits on the back of controlView to trap flash touches */
    @IBOutlet weak var flashView: UIView!

    // MARK: Image Effects
    /** Tracks which effect tool is currently selected in effects: [UIView] */
    var lastSelectedEffect = -1
    var selectedEffect = -1
    
    /** All the effects to be loaded */
    var effects: [AnyObject] = [FilterImageEffect(),
                                DrawImageEffectView(),
                                TextImageEffectView()]
    
    // MARK: Camera Controls & Tools
    // Tools
    /** Container view for effect tools */
    @IBOutlet var effectToolView: UIView!
    /** Container view for effect options */
    @IBOutlet var effectOptionView: UIView!
    @IBOutlet weak var effectOptionViewBottomConstraint: NSLayoutConstraint!
    /** Collection view for effect tool selection */
    var effectToolBubbleCVC: BubbleMenuCollectionViewController!
    /** Collection view for effect option selection */
    var effectOptionBubbleCVC: BubbleMenuCollectionViewController!
    
    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupSatoCamera()
        setupControlView()
        setupEffects()
        setupSnapButton()
        setupTest()
        
        // Finalize setup
        view.bringSubview(toFront: controlView)
        // Must manually select first effect
        selectFirstEffect()
        //satoCamera.start()
        satoCamera.initialStart()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardObserver()

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeKeyboardObserver()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("received memory warning")
    }
    
    deinit {
    }
    
    // MARK: Setups
    
//    func askUserCameraAccessAuthorization(completion: ((_ authorized: Bool)->())?) {
//        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) != AVAuthorizationStatus.authorized {
//            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
//                completion?(granted)
//            })
//        } else {
//            completion?(true)
//        }
//    }
    
    func setupSatoCamera() {
        
        if let sampleBufferView = sampleBufferView {
            sampleBufferView.frame = sampleBufferContainerView.bounds
            sampleBufferView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            sampleBufferContainerView.addSubview(sampleBufferView)

        }

        if let outputImageView = outputImageView {
            outputImageView.frame = outputImageContainerView.bounds
            outputImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            outputImageContainerView.addSubview(outputImageView)
        }
        //view.bringSubview(toFront: outputImageContainerView)
        satoCamera = SatoCamera(frame: view.bounds)
        satoCamera.cameraOutput = self
    }
    
    func setupEffects() {
        // Add each effect
        for effect in effects {
            if let effect = effect as? UIView {
                effect.frame = view.bounds
                effect.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                view.addSubview(effect)
            }
            if let effect = effect as? FilterImageEffect {
                effect.delegate = satoCamera
            }
        }
    }
    
    func setupControlView() {
        // Give control view transparent background
        controlView.backgroundColor = UIColor.clear
        
        // Give menu transparent background
        effectToolView.backgroundColor = UIColor.clear
        effectOptionView.backgroundColor = UIColor.clear
        
        // Setup flashView to trap touches
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedFlashView(_:)))
        flashView.addGestureRecognizer(tap)

        // Setup collection views for menu and options
        setupEffectToolBubbles()
        setupEffectOptionBubbles()
    }
    
    func setupEffectToolBubbles() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = UICollectionViewScrollDirection.horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.itemSize = CGSize(width: 77, height: 77)

        effectToolBubbleCVC = BubbleMenuCollectionViewController(collectionViewLayout: layout)
        effectToolBubbleCVC.datasource = self
        effectToolBubbleCVC.delegate = self
        
        addChildViewController(effectToolBubbleCVC)
        effectToolView.addSubview(effectToolBubbleCVC.view)
        effectToolBubbleCVC.view.frame = effectToolView.bounds
        effectToolBubbleCVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effectToolBubbleCVC.didMove(toParentViewController: self)
    }
    
    func setupEffectOptionBubbles() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = UICollectionViewScrollDirection.horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.itemSize = CGSize(width: 77, height: 77)

        effectOptionBubbleCVC = BubbleMenuCollectionViewController(collectionViewLayout: layout)
        effectOptionBubbleCVC.datasource = self
        effectOptionBubbleCVC.delegate = self
        
        addChildViewController(effectOptionBubbleCVC)
        effectOptionView.addSubview(effectOptionBubbleCVC.view)
        effectOptionBubbleCVC.view.frame = effectOptionView.bounds
        effectOptionBubbleCVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effectOptionBubbleCVC.didMove(toParentViewController: self)
    }
    
    // MARK: Camera controls
    
    func tappedFlashView(_ sender: UITapGestureRecognizer) {
        let touches = sender.value(forKey: "touches") as! [UITouch]
        satoCamera.tapToFocusAndExposure(touch: touches.first!)
    }

    func cancel() {
        satoCamera.reset()
        
        for effect in effects {
            if let effect = effect as? CameraViewBubbleMenu {
                effect.reset()
            }
        }
    }
    
    func save() {        
        let drawImageEffectView = effects[1] as? DrawImageEffectView
        let drawImage = drawImageEffectView?.drawView.imageView.image
        
        let textImageEffectView = effects[2] as? TextImageEffectView
        textImageEffectView?.textView.render()
        let textImage = textImageEffectView?.textView.imageView.image
        
        satoCamera.save(drawImage: drawImage, textImage: textImage, completion: { (saved: Bool) in
            if saved {
                print("saved gif to camera roll")
            } else {
                print("failed to save gif to camera roll")
            }
        })
        
        cancel()
    }
    
    func toggleSelfie() {
        satoCamera.toggleCamera()
    }
    
    func toggleTorch() {
        let state = satoCamera.toggleTorch()
        flashButton.setTitle(state, for: .normal)
        print(state)
    }
    
    // MARK: Selection
    
    /** Select the first tool.  Usually used during setup */
    func selectFirstEffect() {
        let indexPath = IndexPath(row: 0, section: 0)
        // Show selection
        effectToolBubbleCVC.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: .left)
        // Trigger selection action
        effectToolBubbleCVC.delegate?.bubbleMenuCollectionViewController(effectToolBubbleCVC, didSelectItemAt: indexPath)
    }
    
    /** Activates a selected effect and moves other effects to background */
    func didSelectEffect(at indexPath: IndexPath) {
        
        // If it's the same selection, do nothing
        if selectedEffect != indexPath.row {
            lastSelectedEffect = selectedEffect
            selectedEffect = indexPath.row
        }
        
        // Move selected effect view to fore
        // Remove last effect from control view
        if lastSelectedEffect >= 0, let effect = effects[lastSelectedEffect] as? UIView {
            view.insertSubview(effect, belowSubview: controlView)
        }
        // Bring selected effect view to back of control view
        if let effect = effects[selectedEffect] as? UIView {
            controlView.insertSubview(effect, at: 1)
        }
        
        // Tell tool it's been selected
        if let effect = effects[selectedEffect] as? CameraViewBubbleMenu {
            effect.didSelect?(effect)
        }
        
        loadToolOptions()
    }
     
    func loadToolOptions() {
        effectOptionBubbleCVC.collectionView?.reloadData()
    }
    
    // MARK: BubbleMenuCollectionViewControllerDatasource
    
    /** 
     Returns the contents for the applicable bubble menu collection view controller.
     */
    func bubbleMenuContent(for bubbleMenuCollectionViewController: BubbleMenuCollectionViewController) -> [BubbleMenuCollectionViewCellContent] {
        // Check which collection is asking for content, the tool menu or the options menu
        if (bubbleMenuCollectionViewController == effectToolBubbleCVC) {
            // Get the icons for all the effects
            var iconBubbleContents: [BubbleMenuCollectionViewCellContent] = []
            for effect in effects {
                if let effect = effect as? CameraViewBubbleMenu {
                    iconBubbleContents.append(effect.iconContent)
                }
            }
            return iconBubbleContents
        } else if (bubbleMenuCollectionViewController == effectOptionBubbleCVC) {
            // Return the options for the selected effect
            if let effect = effects[selectedEffect] as? CameraViewBubbleMenu {
                return effect.menuContent
            }
        }
        print("Error: BubbleMenu CVC not recognized; cannot provide menu content")
        return []
    }
    
    // MARK: BubbleMenuCollectionViewControllerDelegate

    func bubbleMenuCollectionViewController(_ bubbleMenuCollectionViewController: BubbleMenuCollectionViewController,
                                            didSelectItemAt indexPath: IndexPath) {
        // Check which collection view recieved the selection
        // Selection made on tools menu
        if (bubbleMenuCollectionViewController == effectToolBubbleCVC) {
            didSelectEffect(at: indexPath)
        }
        // Selection made on options menu
        else if (bubbleMenuCollectionViewController == effectOptionBubbleCVC) {
            if let effect = effects[selectedEffect] as? CameraViewBubbleMenu {
                effect.menu(bubbleMenuCollectionViewController, didSelectItemAt: indexPath)
            }
        }
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
        if let showMenu = (effects[selectedEffect] as? CameraViewBubbleMenu)?.showsMenuContentOnKeyboard, showMenu {
            // Get keyboard animation information
            guard let keyboardFrame = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect else {
                print("Error: Cannot retrieve Keyboard frame from keyboard notification")
                return
            }
            guard let animationTime = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double else {
                print("Error: Cannot retrieve animation duration from keyboard notification")
                return
            }
            
            // Save the original position
            lastconstant = effectOptionViewBottomConstraint.constant
            // Enforce the new position above keyboard
            effectOptionViewBottomConstraint.constant = keyboardFrame.height - (44 + 15)
            // Animate the constraint changes
            UIView.animate(withDuration: animationTime, animations: { 
                self.view.layoutIfNeeded()
            })
        }
    }
    
    /** Keyboard appearance notification.  Pushes content (option menu) back to original position when no keyboard is shown */
    func keyboardWillHide(notification: NSNotification) {
        
        // See if menu should be pushed with keyboard
        if let showMenu = (effects[selectedEffect] as? CameraViewBubbleMenu)?.showsMenuContentOnKeyboard, showMenu {
            // Get keyboard animation information
            guard let animationTime = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double else {
                print("Error: Cannot retrienve animation duration from keyboard notification")
                return
            }
            
            // Return to original position
            effectOptionViewBottomConstraint.constant = lastconstant
            // Animate the constraint changes
            UIView.animate(withDuration: animationTime, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
}

@objc protocol CameraViewBubbleMenu {
    /** Contents of the bubble menu */
    var menuContent: [BubbleMenuCollectionViewCellContent] { get }
    /** The icon image of the datasource */
    var iconContent: BubbleMenuCollectionViewCellContent { get }
    /** Flag on whether to show menu content when keyboard appears onscreen */
    @objc optional var showsMenuContentOnKeyboard: Bool { get }
    
    /** Resets to receiver's state */
    func reset()
    /** Called to tell the reciever that an option item was selected */
    func menu(_ sender: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath)
    /** Called to tell the reciever it was selected */
    @objc optional func didSelect(_ sender: CameraViewBubbleMenu)
}
