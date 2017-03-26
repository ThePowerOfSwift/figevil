//
//  KeyboardViewController.swift
//  MeKeyboard
//
//  Created by Jonathan Cheng on 3/24/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import MobileCoreServices

class KeyboardViewController: UIInputViewController, GifCollectionViewControllerDatasource, GifCollectionViewControllerDelegate {

    // MARK: Gif Collection View
    /// Container for Gif Collection View
    let gifContainerView = UIView()
    /// Collection view for gifs
    var gifCVC: GifCollectionViewController!
    /// Model
    var gifContents: [GifCollectionViewCellContent] = []
    
    let nextKeyboardButton = UIButton(type: .system)
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Perform custom UI setup here
        setupGifCollectionView()
        setupNextKeyboardButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh contents of user generated gifs
        loadDatasource()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
    }
    
    /// Add the gif collection view as a child view controller
    func setupGifCollectionView() {
        gifContainerView.frame = view.bounds
        gifContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(gifContainerView)
        
        gifCVC = GifCollectionViewController(collectionViewLayout: collectionViewLayout)
        gifCVC.datasource = self
        gifCVC.delegate = self
        
        addChildViewController(gifCVC)
        gifContainerView.addSubview(gifCVC.view)
        gifCVC.view.frame = gifContainerView.bounds
        gifCVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gifCVC.didMove(toParentViewController: self)
    }
    
    /// Load user generated gifs into VC model
    func loadDatasource() {
        guard let directory = userGeneratedGifURL else {
            print("Error: Directory for user generated gifs cannot be found")
            return
        }
        
        // Get gif contents and load to datasource
        do {
            // Get gif files in application container that end
            let gifURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.pathExtension == gifFileExtension }
            
            gifContents = []
            for url in gifURLs {
                gifContents.append(GifCollectionViewCellContent(url))
            }
        } catch {
            print("Error: Cannot get contents of gif directory \(error.localizedDescription)")
            return
        }
        
        gifCVC.reloadData()
    }
    
    func setupNextKeyboardButton() {
        self.nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), for: [])
        self.nextKeyboardButton.sizeToFit()
        self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        
        self.view.addSubview(self.nextKeyboardButton)
        self.nextKeyboardButton.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.nextKeyboardButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }

    var collectionViewLayout: UICollectionViewLayout {
        get {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = UICollectionViewScrollDirection.horizontal
            layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            layout.minimumInteritemSpacing = 0
            layout.minimumLineSpacing = 0
            layout.itemSize = CGSize(width: 77, height: 77)
            
            return layout
        }
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        // Add custom view sizing constraints here
    }
    
    // MARK: GifCollectionViewDatasource
        
    func gifCollectionViewController(for gifCollectionViewController: GifCollectionViewController) -> [GifCollectionViewCellContent] {
        return gifContents
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
            print("Copied gif to pastedboard")
            
        } catch {
            print("Error: could not read data contents of gif URL at (\(gifURL.path))")
            print("\(error.localizedDescription)")
        }
    }
}
