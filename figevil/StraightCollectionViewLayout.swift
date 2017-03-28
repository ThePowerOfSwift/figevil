//
//  StraightCollectionViewLayout.swift
//  figevil
//
//  Created by Satoru Sasozaki on 3/27/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class StraightCollectionViewLayout: UICollectionViewFlowLayout {

    init(itemSize: CGSize = CGSize(width: 77, height: 77)) {
        super.init()
        self.scrollDirection = UICollectionViewScrollDirection.horizontal
        self.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.minimumInteritemSpacing = 0
        self.minimumLineSpacing = 0
        self.itemSize = itemSize
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
