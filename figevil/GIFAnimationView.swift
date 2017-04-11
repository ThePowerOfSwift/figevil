//
//  ThunderboltView.swift
//  thunderbolt
//
//  Created by Jonathan Cheng on 4/8/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import FLAnimatedImage
import ImageIO

private let defaultSize = CGSize(width: 80, height: 80)

class GIFAnimationView: UIView {
    var gifImageViews: [FLAnimatedImageView] = []
    var gifAnimatedImageMap: [URL: FLAnimatedImage?] = [:]
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    func setup() {
    }

    func addGIF(_ url: URL) {
        // Check if gif data exists in image animation map
        // If it doesn't add it
        if !gifAnimatedImageMap.keys.contains(url)
        {
            do {
                let data = try Data(contentsOf: url)
                gifAnimatedImageMap[url] = FLAnimatedImage(animatedGIFData: data)
            } catch {
                print("Error: GifAnimationView could not get data for gif \(url.path)")
                return
            }
        }
        
        // Create new gif view and add it
        // Setup
        let animatedImageView = FLAnimatedImageView()
        let startPoint = CGPoint(x: frame.maxX / 2, y: frame.maxY / 2)
        animatedImageView.frame.size = defaultSize
        animatedImageView.center = startPoint
        animatedImageView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        
        // GIF Settings
        animatedImageView.animatedImage = gifAnimatedImageMap[url]!
        animatedImageView.contentMode = .scaleAspectFit
        
        // Lay gestures into created text field
        animatedImageView.isUserInteractionEnabled = true
        animatedImageView.isMultipleTouchEnabled = true
        
        // Double tap (to delete)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTappedAnimatedImageView(_:)))
        tap.numberOfTapsRequired = 2
        animatedImageView.addGestureRecognizer(tap)
        // Pan (to move)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pannedAnimatedImageView(_:)))
        animatedImageView.addGestureRecognizer(pan)
        
        // Pinch (to scale)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchedAnimatedImageView(_:)))
        animatedImageView.addGestureRecognizer(pinch)
        
        // Rotation (to rotate)
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotatedAnimatedImageView(_:)))
        animatedImageView.addGestureRecognizer(rotate)

        // Add it to view
        gifImageViews.append(animatedImageView)
        addSubview(animatedImageView)
    }
    
    // MARK: Gesture responders
    
    /** On pinch, resize the textfield and it's contents */
    @objc private func pinchedAnimatedImageView(_ sender: UIPinchGestureRecognizer) {
        print("pinch")
        
        if let animatedImageView = sender.view as? FLAnimatedImageView {
            switch sender.state {
            case .began:
                break
            case .changed:
                break
            case .ended:
                break
            case .cancelled:
                break
            default:
                break
            }
        }
    }
    
    /** Rotate the textfield and contents */
    private var lastRotation: CGFloat = 0
    @objc private func rotatedAnimatedImageView(_ sender: UIRotationGestureRecognizer) {
        print("rotation")
        var originalRotation = CGFloat()
        if sender.state == .began {
            
            // the last rotation is the relative rotation value when rotation stopped last time,
            // which indicates the current rotation
            originalRotation = lastRotation
            
            // sender.rotation renews everytime the rotation starts
            // delta value but not absolute value
            sender.rotation = lastRotation
            
        } else if sender.state == .changed {
            
            let newRotation = sender.rotation + originalRotation
            sender.view?.transform = CGAffineTransform(rotationAngle: newRotation)
            
        } else if sender.state == .ended {
            
            // Save the last rotation
            lastRotation = sender.rotation
        }
    }
    
    /** On double tap remove the textfield */
    @objc private func doubleTappedAnimatedImageView(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
        
        // TODO: cleanup model
    }
    
    /** On pan move the textfield */
    private var originalCenter: CGPoint?
    @objc private func pannedAnimatedImageView(_ sender: UIPanGestureRecognizer) {
        
        if sender.state == UIGestureRecognizerState.began {
            originalCenter = sender.view!.center
        } else if sender.state == UIGestureRecognizerState.changed {
            let translation = sender.translation(in: self)
            sender.view?.center = CGPoint(x: originalCenter!.x + translation.x , y: originalCenter!.y + translation.y)
            
        } else if sender.state == UIGestureRecognizerState.ended {
            
        }
    }

    
    
    /*
    private var imageSource: CGImageSource? {
        if let gifURL = gifURL {
            let sourceOptions: [NSObject: AnyObject] = [kCGImageSourceShouldCache as NSObject: false as AnyObject]
            return CGImageSourceCreateWithURL(gifURL as CFURL, sourceOptions as CFDictionary?)
        }
        return nil
    }
    
    var frameCount: UInt {
        return gifImageView.animatedImage.frameCount
    }
    
    func getFrames(_ frameIndex: [Int]) -> [CGImage] {
        guard let imageSource = imageSource else {
            print("Error: cannot get image source for gif")
            return []
        }
        
        var frames: [CGImage] = []
        let sourceOptions: [NSObject: AnyObject] = [kCGImageSourceShouldCache as NSObject: false as AnyObject]
        
        for idx in frameIndex.filter({ $0 > 0 && $0 <= Int(frameCount) }) {
            if let image = CGImageSourceCreateImageAtIndex(imageSource, idx - 1, sourceOptions as CFDictionary?) {
                frames.append(image)
            }
        }
        return frames
    }*/
}
