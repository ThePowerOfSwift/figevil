//
//  KeyboardViewController.swift
//  MeKeyboard
//
//  Created by Jonathan Cheng on 3/24/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import MobileCoreServices

private let toolbarHeight: CGFloat = 44.0
private let marginBuffer: CGFloat = 7.0

class MeKeyboardViewController: UIInputViewController, GifCollectionViewControllerDatasource, GifCollectionViewControllerDelegate {
    
    // MARK: Gif Collection View
    /// Model
    var gifContents: [GifCollectionViewCellContent] = []
    /// Collection view for gifs
    var gifCVC: GifCollectionViewController!
    
    var collectionViewLayout: UICollectionViewLayout {
        get {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = UICollectionViewScrollDirection.vertical
            layout.sectionInset = UIEdgeInsets(top: marginBuffer, left: marginBuffer, bottom: toolbarHeight + marginBuffer, right: marginBuffer)
            layout.minimumInteritemSpacing = marginBuffer
            layout.minimumLineSpacing = marginBuffer
            layout.itemSize = CGSize.zero
            
            return layout
        }
    }
    
    // MARK: Toolbar
    let toolbar = UIToolbar()

    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup toolbar
        setupToolbar()
        // Setup the gif collection view
        setupGifCollectionView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Order views
        inputView?.bringSubview(toFront: toolbar)
        
        // Refresh contents of user generated gifs
        loadDatasource()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
        print("memory warning")
    }
    
    // Initialize toolbar and add to view
    func setupToolbar() {
        // Appearance
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        // Orientation
        toolbar.sizeToFit()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        inputView?.addSubview(toolbar)
        // Auto layout
        toolbar.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        toolbar.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight)
        // Populate toolbar items
        let nextKeyboardBarButtonItem = UIBarButtonItem(title: "🌐", style: .plain, target: self, action: #selector(nextInputMode))
        let deleteButton = UIBarButtonItem(title: "⌫", style: .plain, target: self, action: #selector(deleteBackward))
        
        let barButtonItems = [nextKeyboardBarButtonItem, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), deleteButton]
        toolbar.setItems(barButtonItems, animated: false)
    }

    func nextInputMode() {
        super.advanceToNextInputMode()
        advanceToNextInputMode()
//        handleInputModeList(from: UIView, with: UIEvent)
    }
    
    func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }
    
    /// Add the gif collection view as a child view controller
    func setupGifCollectionView() {
        guard let inputView = inputView else {
            print("Error: cannot get input view of keyboard to add gif collection")
            return
        }
        
        gifCVC = GifCollectionViewController(collectionViewLayout: collectionViewLayout)
        gifCVC.datasource = self
        gifCVC.delegate = self
        
        addChildViewController(gifCVC)
        inputView.addSubview(gifCVC.view)
        gifCVC.view.frame = inputView.bounds
        gifCVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gifCVC.didMove(toParentViewController: self)
    }
    
    /// Load user generated gifs into VC model
    func loadDatasource() {
        guard let directory = UserGenerated.gifDirectoryURL else {
            print("Error: Directory for user generated gifs cannot be found")
            return
        }
        
        // Get gif contents and load to datasource
        do {
            // Get gif files in application container that end
            let gifURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.pathExtension == "gif" }
            
            gifContents = []
            for url in gifURLs {
                gifContents.append(GifCollectionViewCellContent(url))
                
            }
        } catch {
            print("Error: Cannot get contents of gif directory \(error.localizedDescription)")
            return
        }
        
        gifCVC.collectionView?.reloadData()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        // Add custom view sizing constraints here
    }
    
    // MARK: GifCollectionViewDatasource
        
    func gifCollectionViewCellContent(for gifCollectionViewController: GifCollectionViewController) -> [GifCollectionViewCellContent] {
        return gifContents
    }
    
    func gifCollectionViewCellContent(for gifCollectionViewController: GifCollectionViewController, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let moveItemAt = gifContents.remove(at: sourceIndexPath.row)
        gifContents.insert(moveItemAt, at: destinationIndexPath.row)
        gifCollectionViewController.collectionViewLayout.invalidateLayout()
        //TODO: need to effect the changes permanently (only works for current session right now)
        
    }
    
    func reloadData(for gifCollectionViewController: GifCollectionViewController) {
        loadDatasource()
    }
    
    // MARK: GifCollectionViewDelegate
    
    /// Perform result of user tapping on gif in collection view
    func gifCollectionViewController(_ gifCollectionViewController: GifCollectionViewController, didSelectItemAt indexPath: IndexPath) {
        guard let gifURL = gifContents[indexPath.row].url else  {
            print("Error retrieving gif content of selected cell")
            return
        }
        
        do {
            // Put gif to pasteboard
            UIPasteboard.general.setData(try Data(contentsOf: gifURL), forPasteboardType: kUTTypeGIF as String)
            print("Copied gif to pasteboard")
            
        } catch {
            print("Error: could not read data contents of gif URL at (\(gifURL.path))")
            print("\(error.localizedDescription)")
        }
    }
}
