//
//  CameraInterface.swift
//  thunderbolt
//
//  Created by Jonathan Cheng on 4/16/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class CameraInterfaceView: UIView {

    static let name = "CameraInterfaceView"
 
    @IBOutlet weak var topToolbar: UIToolbar!
    @IBOutlet weak var bottomToolbar: UIToolbar!
    /// Tracks resizing height of bottom toolbar
    private var bottomToolbarHeightAnchor: NSLayoutConstraint?
    var bottomToolbarHeight: CGFloat = 0 {
        didSet {
            bottomToolbarHeightAnchor = bottomToolbar.heightAnchor.constraint(equalToConstant: bottomToolbarHeight)
            bottomToolbarHeightAnchor?.isActive = true
        }
    }
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var primaryMenuView: UIView!
    @IBOutlet weak var primaryMenuViewWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var primaryMenuClipView: UIView!
    @IBOutlet weak var primaryMenuClipViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var primaryMenuClipViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var primaryMenuClipViewBottomConstraint: NSLayoutConstraint!
    
    // Model
    /// State flag for capture or preview mode
    var isCapture = true {
        didSet {
            updateInterface()
        }
    }
    
    // MARK: Interface variables
    
    /// Items for top toolbar when in Capture mode
    var captureTopItems: [UIBarButtonItem] = []
    /// Items for top toolbar when in Preview mode
    var previewTopItems: [UIBarButtonItem] = []
    /// Items for bottom toolbar when in Capture mode
    var captureBottomItems: [UIBarButtonItem] = []
    /// Items for bottom toolbar when in Preview mode
    var previewBottomItems: [UIBarButtonItem] = []

    /// Sets and resizes the capture screen display
    var captureSize: Camera.screen = .square {
        didSet {
            updateCaptureSize()
        }
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
        
        // Sync contents
        updateInterface()
        
        primaryMenuClipView.clipsToBounds = true
        self.layoutIfNeeded()
    }
    
    // MARK: Methods
    
    /// Trigger 'redraw' of capture size
    func updateCaptureSize() {
        let toolbars = [topToolbar!, bottomToolbar!]
        
        switch captureSize {
        case .fullscreen:
            // Make toolbars transparent
            for toolbar in toolbars {
                toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
                toolbar.backgroundColor = UIColor.clear
            }
            // Adjust content size
            contentViewTopConstraint.constant = -topToolbar.frame.height
        case .square:
            // Make toolbars black
            _ = toolbars.map({ $0.barStyle = .black})
            // Adjust content size
            contentViewTopConstraint.constant = 0
        }
        
        // Change the content view height
        contentViewHeightConstraint.constant = captureSize.size().height

        // Animate (autolayout changes above)
        UIView.animate(withDuration: AnimationTime.select) {
            self.layoutIfNeeded()
        }
    }
    
    /// Trigger 'redraw' of interface toolbars
    func updateInterface() {
        // Repopulate top toolbar
        let topItems = isCapture ? captureTopItems : previewTopItems
        topToolbar.setItems(topItems, animated: false)
        topToolbar.tintColor = UIColor.white

        // Resize bottom toolbar
        bottomToolbarHeightAnchor?.isActive = isCapture
        // Repopulate bottom toolbar
        let bottomItems = isCapture ? captureBottomItems : previewBottomItems
        bottomToolbar.setItems(bottomItems, animated: false)
        bottomToolbar.tintColor = UIColor.white
    }
    
    /// Toggle interface mode: Capture vs. Preview
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
}

