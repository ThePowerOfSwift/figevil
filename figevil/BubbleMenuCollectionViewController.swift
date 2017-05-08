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
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register cell classes
        collectionView!.register(cellType, forCellWithReuseIdentifier: cellType.name)
        
        // Configure appearance
        collectionView?.backgroundColor = UIColor.clear
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false
        
        timer = Timer(timeInterval: 3, repeats: false) { (timer: Timer) in
            self.didSelect = false
            self.collectionView?.reloadData()
        }
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
//        if let datasource = datasource {
//            let count = datasource.bubbleMenuContent(for: self).count
//            return count
//        }
//        return 0
        return numberOfItems
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.name, for: indexPath) as! BubbleMenuCollectionViewCell
    
        if !didSelect {
            if let selectedIndexPath = selectedIndexPath {
                if let bubble = datasource?.bubbleMenuContent(for: self)[selectedIndexPath.row] {
                    // Configure the cell
                    cell.bubbleContent = bubble
                    return cell
                }
            }
        }
        
        if let bubble = datasource?.bubbleMenuContent(for: self)[indexPath.row] {
            // Configure the cell
            cell.bubbleContent = bubble
        }
        
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    var didSelect: Bool = false {
        didSet {
            if let datasource = datasource {
                if didSelect {
                    numberOfItems = datasource.bubbleMenuContent(for: self).count
                } else {
                    numberOfItems = 1
                }
                collectionView?.reloadData()
            }
        }
    }
    
    var numberOfItems: Int = 1
    var timer: Timer!
//    var numberOfItems: Int {
//        if let datasource = datasource {
//            if didSelect {
//                return datasource.bubbleMenuContent(for: self).count
//            } else {
//                return 1
//            }
//        }
//        return 0
//    }
    
//    func selectionIntervalDidEnd() {
//        didSelect = false
//        collectionView?.reloadData()
//    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.bubbleMenuCollectionViewController(self, didSelectItemAt: indexPath)
        didSelect = true
        //collectionView.reloadData()
//        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { (timer: Timer) in
//            self.didSelect = false
//            self.collectionView?.reloadData()
//        }
        
        updateNumberOfItems()
    }
    
    var isTouchUpdated: Bool = false

    var selectedIndexPath: IndexPath?
    func updateNumberOfItems() {
        collectionView?.reloadData()
        selectedIndexPath = collectionView?.indexPathsForSelectedItems?[0]
        resetTimer()
    }
    
    // https://stackoverflow.com/questions/31690634/how-to-reset-nstimer-swift-code
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(hideCells), userInfo: "timer", repeats: true)
    }
    
    func hideCells() {
        self.didSelect = false
        self.collectionView?.reloadData()
    }
    
    func resetTimer() {
        timer.invalidate()
        startTimer()
    }
}

protocol BubbleMenuCollectionViewControllerDatasource {
    func bubbleMenuContent(for bubbleMenuCollectionViewController: BubbleMenuCollectionViewController) -> [BubbleMenuCollectionViewCellContent]

}

protocol BubbleMenuCollectionViewControllerDelegate {
    func bubbleMenuCollectionViewController(_ bubbleMenuCollectionViewController: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath)
}
