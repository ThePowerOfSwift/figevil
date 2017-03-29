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
    var gifContent: GifCollectionViewCellContent? {
        didSet {
            didSetGifContent()
        }
    }
    
    // MARK: Storyboard outlets
    @IBOutlet weak var imageView: FLAnimatedImageView!

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
    }
    
    // MARK: Selection and highlight
    
    private func didSelect() {
        print("Did select gif collection view cell")
        UIView.animate(withDuration: selectionAnimationTime / 2) {
        }
    }
    
    private func didDeselect() {
        print("Did deselect gif collection view cell")
        UIView.animate(withDuration: selectionAnimationTime) {
        }
    }
    
    // Performed on highlight
    private func didHighlight() {
        print("Did highlight gif collection view cell")
    }
}

/** Model for GifCollectionViewCellContent */
class GifCollectionViewCellContent: NSObject {
    var url: URL?
    var animatedImage: FLAnimatedImage?
    
    init(_ url: URL) {
        super.init()
        self.url = url
        do {
            let data = try Data(contentsOf: url)
            self.animatedImage = FLAnimatedImage(animatedGIFData: data)
        } catch {
            print("Error: Cannot get data for Gif at \(url.path)")
            print(error.localizedDescription)
        }
        
    }
}
