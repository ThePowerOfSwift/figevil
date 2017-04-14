//
//  Foreground.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/4/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit


class AnimationEffectView: UIView, CameraViewBubbleMenu {

    /** Model */
    var stickerURLs: [URL] = []
    let animationView = AnimationView()
    
    // MARK: CameraViewBubbleMenu
    var menuContent: [BubbleMenuCollectionViewCellContent] = []
    var iconContent = BubbleMenuCollectionViewCellContent(image: UIImage(named: "text.png")!, label: "Sticker")

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
        setupBubbleMenuContent()
    }
    
    func setupAnimationView() {
        animationView.frame = bounds
        animationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(animationView)
    }
    
    func setupBubbleMenuContent() {
        guard let directory = UserGenerated.stickerDirectoryURL else {
            print("Error: Directory for user generated gifs cannot be found")
            return
        }

        // Reset model
        menuContent = []

        // Get gif contents and load to datasource
        do {
            // Get gif files in application container that end
            stickerURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.pathExtension == "png" }
        } catch {
            print("Error: Cannot get contents of sticker directory \(error.localizedDescription)")
            return
        }

        // TODO: need thumbnails?
        for url in stickerURLs {
            guard let image = UIImage(contentsOfFile: url.path) else {
                break
            }
            let filename = url.lastPathComponent.components(separatedBy: ".").first
            menuContent.append(BubbleMenuCollectionViewCellContent(image: image, label: filename!))
        }
    }
    
    // MARK: CameraViewBubbleMenu
    
    func menu(_ sender: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath) {
        animationView.addAnimation(stickerURLs[indexPath.row])
    }
    
    func reset() {
        // TODO
    }

}
