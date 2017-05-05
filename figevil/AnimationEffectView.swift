//
//  Foreground.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/4/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

private let animationExtension = "json"

class AnimationEffectView: UIView, CameraEffect {

    /** Model */
    var stickerURLs: [URL] = []
    let animationView = AnimationView()
    
    // MARK: Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        setupAnimationView()
    }
    
    func setupAnimationView() {
        animationView.frame = bounds
        animationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(animationView)
    }
    
    // MARK: CameraEffect

    var primaryMenu: [BubbleMenuCollectionViewCellContent] {
        guard let directory = UserGenerated.stickerDirectoryURL else {
            print("Error: Directory for user generated gifs cannot be found")
            return []
        }
        
        // Reset model
        var menu: [BubbleMenuCollectionViewCellContent] = []
        
        // Get gif contents and load to datasource
        do {
            // Get gif files in application container that end
            stickerURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.pathExtension == animationExtension }
        } catch {
            print("Error: Cannot get contents of sticker directory \(error.localizedDescription)")
            return []
        }
        
        // TODO: need thumbnails?
        for url in stickerURLs {
            let image = UIImage()
            
            let filename = url.lastPathComponent.components(separatedBy: ".").first
            menu.append(BubbleMenuCollectionViewCellContent(image: image, label: filename!))
        }

        return menu
    }
    
    func didSelectPrimaryMenuItem(_ atIndex: Int) {
        animationView.addAnimation(stickerURLs[atIndex])
    }
    
    func reset() {
        animationView.reset()
    }

}
