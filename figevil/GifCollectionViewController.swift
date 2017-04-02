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

class GifCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, GifCollectionViewCellDelegate, UIGestureRecognizerDelegate {

    var datasource: GifCollectionViewControllerDatasource?
    var delegate: GifCollectionViewControllerDelegate?
    
    // Editing & Reordering
    var isEditingMode = false {
        didSet {
            didSetEditingMode()
        }
    }
    var tap: UITapGestureRecognizer!
    var pan: UIPanGestureRecognizer!
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
         self.clearsSelectionOnViewWillAppear = true

        // Register cell classes
        self.collectionView!.register(cellType, forCellWithReuseIdentifier: cellType.name)

        // Configure appearance
        collectionView?.backgroundColor = UIColor.lightGray
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false

        // Gestures for editing & reordering
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        collectionView?.addGestureRecognizer(longPress)

        tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        pan.delegate = self
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
        cell.isEditingMode = isEditingMode
        
        if let gif = datasource?.gifCollectionViewCellContent(for: self)[indexPath.row] {
            // Configure the cell
            cell.gifContent = gif
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        datasource?.gifCollectionViewCellContent(for: self, moveItemAt: sourceIndexPath, to: destinationIndexPath)
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
    
    // MARK: Methods
    
    // MARK: Editing & Reordering
    
    func didSetEditingMode() {
        
        // Add (or remove) gestures for editing & reordering
        if isEditingMode {
            collectionView?.addGestureRecognizer(tap)
            collectionView?.addGestureRecognizer(pan)
            
        } else {
            collectionView?.removeGestureRecognizer(tap)
            collectionView?.removeGestureRecognizer(pan)
        }
        
        // Tell visible cells to enter (exit) editing mode
        guard let visibleCells = collectionView?.visibleCells else {
            return
        }
        
        for visibleCell in visibleCells {
            if let cell = visibleCell as? GifCollectionViewCell {
                cell.isEditingMode = isEditingMode
            }
        }
    }
    
    func didLongPress(_ sender: UILongPressGestureRecognizer) {
        if isEditingMode {
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
        } else {
            isEditingMode = true
            if let selectedIndexPath = collectionView?.indexPathForItem(at: sender.location(in: collectionView))
            {
                collectionView?.beginInteractiveMovementForItem(at: selectedIndexPath)
            }
        }
    }
    
    func didTap(_ sender: UITapGestureRecognizer) {
        if isEditingMode {
            guard let selectedIndexPath = collectionView?.indexPathForItem(at: sender.location(in: collectionView)) else {
                isEditingMode = false
                return
            }
            let cell = collectionView?.cellForItem(at: selectedIndexPath) as! GifCollectionViewCell
            let location = sender.location(in: cell.deleteButton)

            if cell.deleteButton.point(inside: location, with: nil) {
                cell.deleteTapped(sender, forEvent: nil)
            }
            else {
                isEditingMode = false
            }

        } else {
        }
    }
    
    func didPan(_ sender: UIPanGestureRecognizer) {
        if isEditingMode {
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
    
    // MARK: UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == pan {
            return true
        }
        
        return false
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
