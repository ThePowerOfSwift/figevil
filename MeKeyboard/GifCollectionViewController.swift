//
//  GifCollectionViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/24/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

private let cellType = GifCollectionViewCell.self

class GifCollectionViewController: UICollectionViewController {

    var datasource: GifCollectionViewControllerDatasource?
    var delegate: GifCollectionViewControllerDelegate?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(cellType, forCellWithReuseIdentifier: cellType.name)

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
        if let _ = datasource {
            return 1
        }
        return 0
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let datasource = datasource {
            let count = datasource.gifCollectionViewController(for: self).count
            print("count: \(count)")
            return count
        }
        return 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.name, for: indexPath) as! GifCollectionViewCell
    
        if let gif = datasource?.gifCollectionViewController(for: self)[indexPath.row] {
            // Configure the cell
            cell.gifContent = gif
        }
        return cell
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.gifCollectionViewController(self, didSelectItemAt: indexPath)
    }
    
    // MARK: Methods

    func reloadData() {
        collectionView?.reloadData()
    }
}

protocol GifCollectionViewControllerDatasource {
    func gifCollectionViewController(for gifCollectionViewController: GifCollectionViewController) -> [GifCollectionViewCellContent]
    
}

protocol GifCollectionViewControllerDelegate {
    func gifCollectionViewController(_ gifCollectionViewController: GifCollectionViewController, didSelectItemAt indexPath: IndexPath)
}
