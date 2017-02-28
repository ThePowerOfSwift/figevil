//
//  FilterImageEffect.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/22/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

class FilterImageEffect: NSObject, CameraViewBubbleMenu {

    var menuContent: [BubbleMenuCollectionViewCellContent] = []
    var iconContent = BubbleMenuCollectionViewCellContent(image: UIImage(named: "golden_gate_bridge.jpg")!, label: "Filter")
    var delegate: FilterImageEffectDelegate?
    
    override init() {
        super.init()
        
        setupBubbleMenuContent()
    }
    
    func setupBubbleMenuContent() {
        for filter in Filter.list() {
            let bubble = BubbleMenuCollectionViewCellContent(image: UIImage(named:filter.imageUrlString)!, label: filter.name)
            menuContent.append(bubble)
        }
    }
    
    // MARK: CameraViewBubbleMenu
    
    func menu(_ sender: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath) {
        let filter = Filter.list()[indexPath.row]
        delegate?.didSelectFilter(self, filter: filter)
    }
    
    func reset() {
        
    }
}

protocol FilterImageEffectDelegate {
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?)
}
