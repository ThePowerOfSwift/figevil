//
//  FilterImageEffect.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/22/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

class FilterImageEffect: NSObject, CameraEffect {
    weak var delegate: FilterImageEffectDelegate?

    // MARK: CameraEffect

    var primaryMenu: [BubbleMenuCollectionViewCellContent] {
        var menu: [BubbleMenuCollectionViewCellContent] = []
        for filter in Filter.shared.list {
            let bubble = BubbleMenuCollectionViewCellContent(image: filter.iconImage, label: filter.name)
            menu.append(bubble)
        }
        return menu
    }
    
    func didSelectPrimaryMenuItem(_ atIndex: Int) {
        let filter = Filter.shared.list[atIndex]
        delegate?.didSelectFilter(self, filter: filter)
    }
    
    func reset() {
        
    }
}

protocol FilterImageEffectDelegate: class {
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?)
}
