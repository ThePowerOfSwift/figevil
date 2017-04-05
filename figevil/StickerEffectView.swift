//
//  Foreground.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/4/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit


class StickerEffectView: UIView, CameraViewBubbleMenu {

    /** Model */
    var stickerURLs: [URL] = []
    let imageView = UIImageView()
    
    private static let defaultBubbleContent = BubbleMenuCollectionViewCellContent(image: UIImage(), label: "None")
    
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
        setupForegroundView()
        setupBubbleMenuContent()
    }
    
    func setupForegroundView() {
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }
    
    func setupBubbleMenuContent() {
        guard let directory = UserGenerated.stickerDirectoryURL else {
            print("Error: Directory for user generated gifs cannot be found")
            return
        }

        // Reset model
        menuContent = [StickerEffectView.defaultBubbleContent]

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
        imageView.image = menuContent[indexPath.row].image
    }
    
    func reset() {
        imageView.image = nil
    }

}
