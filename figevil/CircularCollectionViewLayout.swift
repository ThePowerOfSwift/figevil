//
//  CircularCollectionViewLayout.swift
//  CircularCollectionView
//
//  Created by Satoru Sasozaki on 3/10/17.
//  Copyright © 2017 Rounak Jain. All rights reserved.
//

import UIKit


/** Attibutes for each item. */
class CircularCollectionViewLayoutAttributes: UICollectionViewLayoutAttributes {
    var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    var angle: CGFloat = 0 {
        didSet {
            // not needed because we won't use z axis
            zIndex = Int(angle * 1000000)
            
            // transform is a property of UICollectionViewLayoutAttributes class which define the affine transform of the item.
            transform = CGAffineTransform(rotationAngle: angle)
        }
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        // can i apply the same deep copy logic to buffer coping?
        
        // copy things in super class
        let copiedAttributes: CircularCollectionViewLayoutAttributes = super.copy(with: zone) as! CircularCollectionViewLayoutAttributes
        // copy things in subclass here
        copiedAttributes.anchorPoint = self.anchorPoint
        copiedAttributes.angle = self.angle
        return copiedAttributes
    }
}

class CircularCollectionViewLayout: UICollectionViewLayout {
    
    let itemSize = CGSize(width: 133, height: 173)
    
    var angleAtExtreme: CGFloat {
        var angle: CGFloat = 0.0
        if collectionView!.numberOfItems(inSection: 0) > 0 {
            angle = -CGFloat(collectionView!.numberOfItems(inSection: 0) - 1) * anglePerItem
        }
        return angle
    }
    
    /** angle increases as you scroll increasing content offset.
     subtract this value from (anglePerItem * item index) which is the fixed coordinate of each item
     to scroll circularly based on the current content offset. */
    var angle: CGFloat {
        let maxOffset = collectionView!.contentSize.width - collectionView!.bounds.width
        let rate = collectionView!.contentOffset.x / maxOffset
        let currentAngle = angleAtExtreme * rate
        return currentAngle
    }
    
    var radius: CGFloat = 500 {
        didSet {
            invalidateLayout()
        }
    }
    
    var anglePerItem: CGFloat {
        return atan(itemSize.width / radius)
    }
    
    override var collectionViewContentSize: CGSize {
        let width = CGFloat(collectionView!.numberOfItems(inSection: 0)) * itemSize.width
        let height = collectionView!.bounds.height
        let size = CGSize(width: width, height: height)
        
        return size
    }
    
    /** Tells the collection view that I'll be using CircularCollectionViewLayoutAttributes but not the default UICollectionViewLayoutAttricutes.*/
    override class var layoutAttributesClass: AnyClass {
        return CircularCollectionViewLayoutAttributes.self
    }
    
    var attributesList = [CircularCollectionViewLayoutAttributes]()
    
    /** Called the first time collection view appears on screen. Also called when the layout is invalidated. */
    override func prepare() {
        super.prepare()
        
        print("collection view in layout class: \(collectionView)")
        // http://stackoverflow.com/questions/27515673/whats-causing-this-ios-crash-uicollectionview-received-layout-attributes-for-a
        attributesList.removeAll()
        let centerX = collectionView!.contentOffset.x + collectionView!.bounds.width / 2.0
        
        // map creates a new array with the result of the closure for each element
        attributesList = (0..<collectionView!.numberOfItems(inSection: 0)).map({ (i) -> CircularCollectionViewLayoutAttributes in
            let attributes = CircularCollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            attributes.size = self.itemSize
            // cell Y position
//            attributes.center = CGPoint(x: centerX, y: collectionView!.bounds.height / 5)
            attributes.center = CGPoint(x: centerX, y: 10.0)
            attributes.angle = self.angle + (anglePerItem * CGFloat(i))
            
            // anchor point is a property of CALayer defined in unit coordinate system
            // thus dividing by itemSize.height is nessesary. result is over 1
            let anchorPointY = ((itemSize.height / 2.0) + radius) / itemSize.height - 1
            // anchor point by default is (0.5, 0.5) which is the center of the layer's bounds rectangle.
            attributes.anchorPoint = CGPoint(x: 0.5, y: anchorPointY)
            
            return attributes
        })
    }
    
    // These two methods are called by layout many times and it's better to keep it efficient.
    // so attributes list is cached in prepare()
    /** Returns the layout attributes for all of the cells and views in the specified rectangle.*/
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // rect is (0.0, 0.0, 736.0, 736.0)
        var attr = [CircularCollectionViewLayoutAttributes]()
        for i in 0..<collectionView!.numberOfSections {
//            for k in 0..<collectionView!.numberOfItems(inSection: 0) {
//                let indexPath = IndexPath(item: k, section: i)
//                attr.append(layoutAttributesForItem(at: indexPath) as! CircularCollectionViewLayoutAttributes)
//            }
            for k in 0..<3 {
                let indexPath = IndexPath(item: k, section: i)
                attr.append(layoutAttributesForItem(at: indexPath) as! CircularCollectionViewLayoutAttributes)
            }
        }
        print("number of attributes: \(attr.count) in \(#function)")
        return attr
//        return attributesList
    }
    
    /** Returns the layout information for the item at the specified index. */
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        print("indexPath.item: \(indexPath.item) in \(#function)")
        return attributesList[indexPath.item]
    }
    
    /** Returning true tells the colleciont view to invalidate its layout as it scrolls, which in turn calls prepareLayout where you can re-calculate the cells' layout with updated angular positions. */
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}
