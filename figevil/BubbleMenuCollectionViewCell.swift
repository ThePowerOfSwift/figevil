//
//  BubbleMenuCollectionViewCell.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/20/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

class BubbleMenuCollectionViewCell: UICollectionViewCell {
    static let name = "BubbleMenuCollectionViewCell"
    
    weak var collectionView: UICollectionView?
    var isCircularLayout: Bool = false
    
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
    
    /** Model */
    var bubbleContent: BubbleMenuCollectionViewCellContent? {
        didSet {
            didSetBubbleContent()
        }
    }
    
    // MARK: Storyboard outlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageLabel: UILabel!
    
    // Manage selection animation
    /** Selection animation duration */
    var animationTime = 0.25
    /** The default font imageLabel is initialized with (set in storyboard) */
    var imageLabelDefaultFont: UIFont?
    /** The selected font for imageLabel */
    var imageLabelSelectedFont: UIFont?

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
        let view = Bundle.main.loadNibNamed(BubbleMenuCollectionViewCell.name, owner: self, options: nil)?.first as! UIView
        // Resize to fill container
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        // Add nib view to self
        self.contentView.addSubview(view)
        
        imageLabelDefaultFont = imageLabel.font
        let boldFontDescriptor = imageLabelDefaultFont!.fontDescriptor.withSymbolicTraits(.traitBold)
        let boldFont = UIFont(descriptor: boldFontDescriptor!, size: imageLabelDefaultFont!.pointSize)
        imageLabelSelectedFont = boldFont

        prepareForReuse()
    }
    
    // MARK: Content methods
    
    private func didSetBubbleContent() {
        if let bubbleContent = bubbleContent {
            imageView.image = bubbleContent.image
            imageLabel.text = bubbleContent.label
        } else {
            imageView.image = nil
            imageLabel.text = ""
        }
    }
    
    override func prepareForReuse() {
        bubbleContent = nil

        didDeselect()
        
        // Backgrounds and selection
        self.contentView.backgroundColor = UIColor.clear
        self.isSelected = false
        
        // Image view
        imageView.layer.cornerRadius = imageView.frame.size.width / 2
        imageView.clipsToBounds = true
        imageView.layer.backgroundColor = UIColor.clear.cgColor
        
        isCircularLayout = false
    }
    
    // MARK: Selection and highlight
    
    private func didSelect() {
        UIView.animate(withDuration: animationTime/2) {
            self.imageView.alpha = 0.25
            self.imageView.layer.borderColor = UIColor.white.cgColor
            self.imageView.layer.borderWidth = 2.0
            
            self.imageLabel.font = self.imageLabelSelectedFont
        }
    }
    
    private func didDeselect() {
        UIView.animate(withDuration: animationTime) {
            self.imageView.alpha = 1.0
            self.imageView.layer.borderWidth = 0.0

            self.imageLabel.font = self.imageLabelDefaultFont
        }
    }
    
    // Performed on highlight
    private func didHighlight() {
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        //super.apply(layoutAttributes)
        
        if isCircularLayout {
            if let circularLayoutAttributes = layoutAttributes as? CircularCollectionViewLayoutAttributes {
                self.layer.anchorPoint = circularLayoutAttributes.anchorPoint
                self.center.y += (circularLayoutAttributes.anchorPoint.y - 0.5) * self.bounds.height
                print("layout attibutes: \(layoutAttributes.transform)")
            }
        }
//        if let collectionView = collectionView {
//            if !collectionView.collectionViewLayout.isKind(of: UICollectionViewFlowLayout.self) {
//                super.apply(layoutAttributes)
//                let circularLayoutAttributes = layoutAttributes as! CircularCollectionViewLayoutAttributes
//                self.layer.anchorPoint = circularLayoutAttributes.anchorPoint
//                self.center.y += (circularLayoutAttributes.anchorPoint.y - 0.5) * self.bounds.height
//                print("collection view layout is circular layout")
//            } else {
//                print("collection view layout is flow layout")
//            }
//            
//        } else {
//            print("collection view is nil in \(#function)")
//        }
        
    }
}

/** Model for BubbleMenuCollectionViewCell */
class BubbleMenuCollectionViewCellContent: NSObject {
    var image: UIImage!
    var label: String!
    
    init(image: UIImage, label: String) {
        super.init()
        self.image = image
        self.label = label
    }
    
}
