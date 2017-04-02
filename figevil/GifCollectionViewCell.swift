//
//  GifCollectionViewCell.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/24/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import FLAnimatedImage

class GifCollectionViewCell: UICollectionViewCell {

    static let name = "GifCollectionViewCell"
    
    /** Model */
    var gifContent: GifCollectionViewCellContent? {
        didSet {
            didSetGifContent()
        }
    }
    
    var isEditingMode = false {
        didSet {
            didSetEditingMode()
        }
    }

    // Highlights are triggered by touch (one tap = highlight + unhiglight)
    /** Override flag to animate highlight on change */
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                didHighlight()
            }
        }
    }
    
    /** Override flag to animate selection on change */
    override var isSelected: Bool {
        didSet {
            if isSelected {
                didSelect()
            } else {
                didDeselect()
            }
        }
    }
    
    var delegate: GifCollectionViewCellDelegate?
    
    // MARK: Storyboard outlets
    @IBOutlet weak var imageView: FLAnimatedImageView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var deleteButton: UIButton!

    // MARK: Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    /**
     Common intialization called after init
     */
    private func setup() {
        // Load nib
        let view = Bundle.main.loadNibNamed(GifCollectionViewCell.name, owner: self, options: nil)?.first as! UIView
        // Resize to fill container
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        // Add nib view to self
        self.contentView.addSubview(view)
        
        prepareForReuse()
    }

    // MARK: Content methods
    
    private func didSetGifContent() {
        if let gifContent = gifContent {
            imageView.animatedImage = gifContent.animatedImage
        } else {
            imageView.animatedImage = nil
        }
    }
    
    override func prepareForReuse() {
        gifContent = nil
        didDeselect()
        
        // Image view
        imageView.layer.cornerRadius = 5
        imageView.clipsToBounds = true
        imageView.layer.backgroundColor = UIColor.clear.cgColor
        
        // Overlay view
        overlayView.layer.cornerRadius = 5
        overlayView.clipsToBounds = true
        overlayView.alpha = 0
        overlayView.isHidden = true
        
        // Delete Button
        deleteButton.isHidden = true
    }
    
    // MARK: Selection and highlight
    
    private func didSelect() {
        self.overlayView.isHidden = false
        UIView.animate(withDuration: selectionAnimationTime / 2, animations: {
            self.overlayView.alpha = 1
        }) { (success) in
            if success {
                UIView.animate(withDuration: 4.0, animations: {
                    self.overlayView.alpha = 0
                }, completion: { (success) in
                    if success {
                        self.overlayView.isHidden = true
                    }
                })
            }
        }
    }
    
    private func didDeselect() {
        UIView.animate(withDuration: selectionAnimationTime, animations: {
            self.overlayView.alpha = 0
        }, completion: { (success) in
            self.overlayView.isHidden = true
        })
    }
    
    // Performed on highlight
    private func didHighlight() {
    }
    
    private func didSetEditingMode() {
        if isEditingMode {
            deleteButton.isHidden = false
        } else {
            deleteButton.isHidden = true
        }
    }
    
    func toggleEditingMode() {
        isEditingMode = !isEditingMode
    }

    @IBAction func deleteTapped(_ sender: Any, forEvent event: UIEvent?) {
        delegate?.remove(self)
    }
}

@objc protocol GifCollectionViewCellDelegate: class {
    func remove(_ sender: GifCollectionViewCell)
}

/** Model for GifCollectionViewCellContent */
class GifCollectionViewCellContent: NSObject {
    var url: URL?
    var animatedImage: FLAnimatedImage? {
        get {
            guard let url = url else {
                return nil
            }
            do {
                let data = try Data(contentsOf: url)
                return FLAnimatedImage(animatedGIFData: data)
            } catch {
                print("Error: Cannot get data for Gif at \(url.path)")
                print(error.localizedDescription)
                return nil
            }
        }
    }
    
    init(_ url: URL) {
        super.init()
        self.url = url
    }
}