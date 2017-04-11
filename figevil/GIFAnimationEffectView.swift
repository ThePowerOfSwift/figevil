//
//  GIFAnimationEffectView.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/10/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import ImageIO

private let gifExtension = "gif"
private let maxPixelSize = max(40, 40)
private let defaultName = "NoName"

class GIFAnimationEffectView: UIView, CameraViewBubbleMenu {

    /** Model */
    var gifAnimationView = GIFAnimationView()
    var gifURLs: [URL] = []
    
    // MARK: CameraViewBubbleMenu variables
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
        setupMenuContent()
    }

    func setupAnimationView() {
        gifAnimationView.frame = bounds
        gifAnimationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(gifAnimationView)
    }
    
    func setupMenuContent() {
        setupGIFURLs()

        let sourceOptions: [NSObject: AnyObject] = [kCGImageSourceShouldCache as NSObject: false as AnyObject,
                                                    kCGImageSourceThumbnailMaxPixelSize as NSObject: maxPixelSize as AnyObject,
                                                    kCGImageSourceCreateThumbnailFromImageIfAbsent: true as AnyObject]
        
        for url in gifURLs {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary?) else {
                print("Error: GIFAnimation Bubble menu failed, cannot load image source for gif animation \(url.path)")
                break
            }
            // TODO: Replace gif frame thumbnail approximation
            let frameIndex = (CGImageSourceGetCount(imageSource) / 2) + 10
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, frameIndex, sourceOptions as CFDictionary?) else {
                print("Error: GIFAnimation Bubble menu failed, cannot get thumbnail CGImage \(url.path)")
                break
            }
            let image = UIImage(cgImage: cgImage)
            let filename = url.lastPathComponent.components(separatedBy: ".").first
            menuContent.append(BubbleMenuCollectionViewCellContent(image: image, label: filename ?? defaultName))
        }
        
    }
    
    func setupGIFURLs() {
        guard let directory = UserGenerated.stickerDirectoryURL else {
            print("Error: GIFAnimation Bubble menu failed, directory for user generated gifs cannot be found")
            return
        }
        
        // Get gif contents and load to datasource
        do {
            // Get gif files in application container that end
            gifURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.pathExtension == gifExtension }
        } catch {
            print("Error: GIFAnimation Bubble menu failed, cannot get contents of sticker directory \(error.localizedDescription)")
            return
        }
    }
    
    func reset() {
    }
    
    func menu(_ sender: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath) {
        gifAnimationView.addGIF(gifURLs[indexPath.row])
    }

}
