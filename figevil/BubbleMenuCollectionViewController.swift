//
//  BubbleMenuCollectionViewController.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/20/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

private let cellType = BubbleMenuCollectionViewCell.self

class BubbleMenuCollectionViewController: UICollectionViewController {
    
    var datasource: BubbleMenuCollectionViewControllerDatasource?
    var delegate: BubbleMenuCollectionViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register cell classes
        collectionView!.register(cellType, forCellWithReuseIdentifier: cellType.name)
        
        // Configure appearance
        collectionView?.backgroundColor = UIColor.clear
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        collectionView.collectionViewLayout.invalidateLayout()

        if let _ = datasource {
            return 1
        }
        return 0
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let datasource = datasource {
            let count = datasource.bubbleMenuContent(for: self).count
            return count
            //return 3
        }
        return 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.name, for: indexPath) as! BubbleMenuCollectionViewCell
    
        if let bubble = datasource?.bubbleMenuContent(for: self)[indexPath.row] {
            // Configure the cell
            cell.bubbleContent = bubble
        }
        
        if !collectionView.collectionViewLayout.isKind(of: UICollectionViewFlowLayout.self) {
            print("collection view layout is circular layout")
            cell.isCircularLayout = true
        } else {
            print("collection view layout is flow layout")
            cell.isCircularLayout = false
        }
        
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.bubbleMenuCollectionViewController(self, didSelectItemAt: indexPath)
    }
}

protocol BubbleMenuCollectionViewControllerDatasource {
    func bubbleMenuContent(for bubbleMenuCollectionViewController: BubbleMenuCollectionViewController) -> [BubbleMenuCollectionViewCellContent]

}

protocol BubbleMenuCollectionViewControllerDelegate {
    func bubbleMenuCollectionViewController(_ bubbleMenuCollectionViewController: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath)
}
