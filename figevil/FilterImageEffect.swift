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
        return Filter.shared.list.map({ BubbleMenuCollectionViewCellContent(image: $0.iconImage, label: $0.name) })
    }
    
    func didSelectPrimaryMenuItem(_ atIndex: Int) {
        let filter = Filter.shared.list[atIndex]
        delegate?.didSelectFilter(self, filter: filter)
    }
    
    func reset() {
        didSelectPrimaryMenuItem(0)
    }
}

protocol FilterImageEffectDelegate: class {
    func didSelectFilter(_ sender: FilterImageEffect, filter: Filter?)
}
