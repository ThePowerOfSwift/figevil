//
//  CameraInterface.swift
//  thunderbolt
//
//  Created by Jonathan Cheng on 4/16/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

protocol CameraInterfaceViewDelegate: class {
    func tappedCapture(_ cameraInterfaceView: CameraInterfaceView)
    func tappedFlash(_ cameraInterfaceView: CameraInterfaceView)
    func tappedLoad(_ cameraInterfaceView: CameraInterfaceView)
    func tappedCancel(_ cameraInterfaceView: CameraInterfaceView)
    func tappedShare(_ cameraInterfaceView: CameraInterfaceView)
    func tappedSelfie(_ cameraInterfaceView: CameraInterfaceView)
}

class CameraInterfaceView: UIView {

    static let name = "CameraInterfaceView"
 
    @IBOutlet weak var topToolbar: UIToolbar!
    @IBOutlet weak var bottomToolbar: UIToolbar!
    @IBOutlet weak var primaryMenuView: UIView!
    @IBOutlet weak var secondaryMenuView: UIView!
    @IBOutlet weak var contentView: UIView!
    
    // Model
    /// State flag for capture or preview mode
    var isCapture = true {
        didSet {
            updateInterface()
        }
    }
    
    weak var delegate: CameraInterfaceViewDelegate?
    
    // MARK: Interface items
    
    /// Items for top toolbar when in Capture mode
    var captureTopItems: [UIBarButtonItem] {
        let liveBarButtonItem = UIBarButtonItem(title: "LIVE", style: .plain, target: nil, action: nil)
        let yellow = UIColor(displayP3Red: 248/255, green: 211/255, blue: 76/255, alpha: 1.0)
        liveBarButtonItem.setTitleTextAttributes([NSForegroundColorAttributeName: yellow], for: .normal)
        liveBarButtonItem.isEnabled = false
        
        // TODO: Implement download
        let downloadButton = UIBarButtonItem(image: #imageLiteral(resourceName: "downloads"), style: .plain, target: self, action: #selector(tappedLoad(_:)))
        downloadButton.isEnabled = false
        
        return [UIBarButtonItem(image: #imageLiteral(resourceName: "flash"), style: .plain, target: self, action: #selector(tappedFlash(_:))),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                liveBarButtonItem,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                downloadButton]
    }
    
    /// Items for top toolbar when in Preview mode
    var previewTopItems: [UIBarButtonItem] {
        return [UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(tappedCancel(_:))),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(tappedShare(_:)))]
    }
    
    private let circleImage = #imageLiteral(resourceName: "circle")
    var circleBarButton: UIBarButtonItem {
        return UIBarButtonItem(image: circleImage, style: .plain, target: self, action: #selector(tappedCapture(_:)))
    }
    
    /// Items for bottom toolbar when in Capture mode
    var captureBottomItems: [UIBarButtonItem] {
        return [UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                circleBarButton,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(image: #imageLiteral(resourceName: "selfie"), style: .plain, target: self, action: #selector(tappedSelfie(_:)))]
    }
    
    /// Items for bottom toolbar when in Preview mode
    var previewBottomItems: [UIBarButtonItem] {
        return [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                circleBarButton,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)]
    }
    
    // MARK: Lifecycle
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    private func setup() {
        // Load nib
        let view = Bundle.main.loadNibNamed(CameraInterfaceView.name, owner: self, options: nil)?.first as! UIView
        // Resize to fill container
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        // Add nib view to self
        addSubview(view)

        // Setup bottom toolbar anchored around circleImage (snap button)
        let bottomBarHeight = circleImage.size.height + 20
        bottomToolbar.heightAnchor.constraint(equalToConstant: bottomBarHeight).isActive = true
        
        // Sync contents
        isCapture = true
    }
    
    // MARK: Methods
    /// Trigger 'redraw' of interface toolbars
    func updateInterface() {
        let topItems = isCapture ? captureTopItems : previewTopItems
        topToolbar.setItems(topItems, animated: false)
        topToolbar.tintColor = UIColor.white
        
        let bottomItems = isCapture ? captureBottomItems : previewBottomItems
        bottomToolbar.setItems(bottomItems, animated: false)
        bottomToolbar.tintColor = UIColor.white
    }
    
    /// Toggle interface mode
    func toggleInterface() {
        isCapture = !isCapture
    }
    
    /// Resets to Capture mode
    func reset() {
        isCapture = true
    }
    
    /// Flashes the status across interface
    func update(with status: String) {
        // TODO: Flash status across screen
        print("status: \(status)")
    }
    
    // MARK: CameraInterfaceViewDelegate

    func tappedCapture(_ sender: Any) {
        delegate?.tappedCapture(self)
    }

    func tappedFlash(_ sender: Any) {
        delegate?.tappedFlash(self)
    }
    
    func tappedLoad(_ sender: Any) {
        delegate?.tappedLoad(self)
    }
    
    func tappedCancel(_ sender: Any) {
        delegate?.tappedCancel(self)
    }
    
    func tappedShare(_ sender: Any) {
        delegate?.tappedShare(self)
    }
    
    func tappedSelfie(_ sender: Any) {
        delegate?.tappedSelfie(self)
    }
}
