//
//  GifCollectionViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/24/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import ImageIO

private let cellType = GifCollectionViewCell.self

class GifCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, GifCollectionViewCellDelegate {

    var datasource: GifCollectionViewControllerDatasource?
    var delegate: GifCollectionViewControllerDelegate?
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
         self.clearsSelectionOnViewWillAppear = true

        // Register cell classes
        self.collectionView!.register(cellType, forCellWithReuseIdentifier: cellType.name)

        // Configure appearance
        collectionView?.backgroundColor = UIColor.clear
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false

        // Add long press for movement
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        collectionView?.addGestureRecognizer(longPress)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        if let _ = datasource {
            return 1
        }
        return 0
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let datasource = datasource {
            let count = datasource.gifCollectionViewCellContent(for: self).count
            return count
        }
        return 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.name, for: indexPath) as! GifCollectionViewCell
        cell.delegate = self
        
        if let gif = datasource?.gifCollectionViewCellContent(for: self)[indexPath.row] {
            // Configure the cell
            cell.gifContent = gif
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        datasource?.gifCollectionViewCellContent(for: self, moveItemAt: sourceIndexPath, to: destinationIndexPath)
    }
    
    // MARK: GifCollectionViewCellDelegate
    
    func remove(_ sender: GifCollectionViewCell) {
        guard let url = sender.gifContent?.url else {
            print("Error: No url to delete")
            return
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            datasource?.reloadData(for: self)
        } catch {
            print("Error: cannot delete file at url \(url.path)")
            print(error.localizedDescription)
        }
    }
    
    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.gifCollectionViewController(self, didSelectItemAt: indexPath)
    }
    
    // MARK: UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size = CGSize(width: 150, height: 150)
        
        // Calculate item size depending on orientation and max length

        let url = datasource?.gifCollectionViewCellContent(for: self)[indexPath.row].url
        guard let datasource = CGImageSourceCreateWithURL(url as! CFURL, nil) else {
            print("Error: Cannot create CGImage datasource for collection view item sizing")
            return size
        }

        let sourceOptions: [NSObject: AnyObject] = [kCGImageSourceShouldCache as NSObject: false as AnyObject]
        guard let properties = CGImageSourceCopyPropertiesAtIndex(datasource, 0, sourceOptions as CFDictionary?) as Dictionary? else {
            return size
        }
        
        let width = properties[kCGImagePropertyPixelWidth] as! CGFloat
        let height = properties[kCGImagePropertyPixelHeight] as! CGFloat

        var scale: CGFloat
        scale = width >= height ? width / size.width : height / size.height        
        size = CGSize(width: width / scale, height: height / scale)
        
        return size
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    
    // MARK: Methods
    
    // MARK: Reordering
    
    func didLongPress(_ sender: UILongPressGestureRecognizer) {
        
        // Trigger cell item movement
        switch sender.state {
        case .began:
            if let selectedIndexPath = collectionView?.indexPathForItem(at: sender.location(in: collectionView))
            {
                collectionView?.beginInteractiveMovementForItem(at: selectedIndexPath)
            }
        case .changed:
            collectionView?.updateInteractiveMovementTargetPosition(sender.location(in: sender.view!))
            
        case .ended:
            collectionView?.endInteractiveMovement()
            
        default:
            collectionView?.cancelInteractiveMovement()
        }
    }

}

protocol GifCollectionViewControllerDatasource {
    /// Returns the data for collection view contents
    func gifCollectionViewCellContent(for gifCollectionViewController: GifCollectionViewController) -> [GifCollectionViewCellContent]
    /// Moves the data of the collection view contents
    func gifCollectionViewCellContent(for gifCollectionViewController: GifCollectionViewController, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
    /// Force reload data
    func reloadData(for gifCollectionViewController: GifCollectionViewController)
    
}

protocol GifCollectionViewControllerDelegate {
    func gifCollectionViewController(_ gifCollectionViewController: GifCollectionViewController, didSelectItemAt indexPath: IndexPath)
}
