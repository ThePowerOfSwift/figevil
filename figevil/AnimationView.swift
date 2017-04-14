//
//  AnimationView.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/12/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import AVFoundation
import ImageIO

class AnimationView: UIView {
    
    // MARK: Model
    var animationImageViews: [UIImageView] = []
    var imageMap: [URL: UIImage] = [:]
    
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
        
    }
    
    func addAnimation(_ url: URL) {
        // Map UIImage
        if !imageMap.keys.contains(url) {
            do {
                let data = try Data(contentsOf: url)
                imageMap[url] = UIImage(data: data)
            } catch {
                print("Error: Cannot get animation image data")
            }
        }
        
        guard let image = imageMap[url] else {
            print("Error: Cannot retrieve animation image")
            return
        }
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        imageView.frame.size = image.size
        imageView.center = center
        addSubview(imageView)
        animationImageViews.append(imageView)
        
        startAnimation(imageView)

        // Gestures
        imageView.isUserInteractionEnabled = true
        // Double tap (to delete)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(tap)
        // Pan (to move)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        imageView.addGestureRecognizer(pan)
        // Pinch (to scale)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        imageView.addGestureRecognizer(pinch)
        // Rotation (to rotate)
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:)))
        imageView.addGestureRecognizer(rotate)
    }
    
    func startAnimation(_ imageView: UIImageView) {
        setAnimation(imageView.layer)
    }
    
    func stopAnimation(_ imageView: UIImageView) {
        imageView.layer.removeAllAnimations()
    }
    
    func setAnimation(_ layer: CALayer) {
        
        let beginTime = 1.0
        
        // Add animations
//        let opacity = CABasicAnimation(keyPath: "opacity")
//        opacity.isRemovedOnCompletion = false
//        opacity.beginTime = CACurrentMediaTime() + beginTime
//        opacity.fromValue = 0.0
//        opacity.toValue = 1.0
//        opacity.duration = 0.5
//        opacity.fillMode = kCAFillModeBackwards
//        opacity.repeatCount = HUGE
//        layer.add(opacity, forKey: "opacity")
        
        let quiver = CABasicAnimation(keyPath: "transform.rotation")
        quiver.isRemovedOnCompletion = false
        quiver.beginTime =  CACurrentMediaTime() + beginTime
        let startAngle: Float = -5.25 * Float.pi / Float(180.0)
        let stopAngle: Float = -startAngle
        quiver.fromValue = startAngle
        quiver.toValue = stopAngle * 5.25
        quiver.autoreverses = true
        quiver.duration = 0.075
        quiver.repeatCount = 5
        let random: CFTimeInterval = Double(arc4random_uniform(50)) / 100
        quiver.timeOffset = random
        
        layer.add(quiver, forKey: "quiver")
    }
    
    // MARK: Gestures
    /// The last rotation is the relative rotation value when rotation stopped last time, which indicates the current rotation
    private var lastRotation: CGFloat = 0
    /// To store original center position for panned gesture
    private var originalCenter: CGPoint?

    /// On pan move the view
    @objc private func panned(_ sender: UIPanGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.began {
            originalCenter = sender.view!.center
        } else if sender.state == UIGestureRecognizerState.changed {
            
            let translation = sender.translation(in: self)
            sender.view?.center = CGPoint(x: originalCenter!.x + translation.x , y: originalCenter!.y + translation.y)
            
        } else if sender.state == UIGestureRecognizerState.ended {
        }
    }

    /// Rotate
    @objc private func rotated(_ sender: UIRotationGestureRecognizer) {

        var originalRotation = CGFloat()
        if sender.state == .began {
            // the last rotation is the relative rotation value when rotation stopped last time,
            // which indicates the current rotation
            originalRotation = lastRotation
            
            // sender.rotation renews everytime the rotation starts
            // delta value but not absolute value
            sender.rotation = lastRotation
            
            stopAnimation(sender.view! as! UIImageView)
            
        } else if sender.state == .changed {
            let newRotation = sender.rotation + originalRotation
            sender.view?.transform = CGAffineTransform(rotationAngle: newRotation)
        } else if sender.state == .ended {
            // Save the last rotation
            lastRotation = sender.rotation
            
            startAnimation(sender.view! as! UIImageView)
        }
    }
    
    /// On double tap remove
    @objc private func doubleTapped(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? UIImageView else {
            print("Error: did not find animation ImageView to remove")
            return
        }
        
        imageView.removeFromSuperview()
        guard let index = animationImageViews.index(of: imageView) else {
            print("Error: did not find animation ImageView in animations array")
            return
        }
        animationImageViews.remove(at: index)
    }
    
    /// On pinch, resize
    @objc private func pinched(_ sender: UIPinchGestureRecognizer) {
        guard let view = sender.view else {
            print("Error: failed to get animation view to resize")
            return
        }
        
        if sender.state == .changed || sender.state == .ended {
            let scale = sender.scale
            let frame = view.frame
            view.frame.size = CGSize(width: frame.width * scale, height: frame.height * scale)
            sender.scale = 1.0
        }
    }
    
    // MARK: Rendering
    func overlayAnimationsToVideo(at url: URL, outputURL: URL, completion: (()->())?) {
        let urlAsset = AVURLAsset(url: url)
        // Setup video composition to overlay animations and export
        let videoComposition = AVMutableVideoComposition(propertiesOf: urlAsset)
        let renderRect = CGRect(origin: CGPoint.zero, size: videoComposition.renderSize)
        
        // Make animation layer to superimpose on video
        let animationLayer = CALayer()
        animationLayer.frame = frame
        animationLayer.isGeometryFlipped = true
        
        // Set video layer as "backing" layer (to be overlaid on)
        let videoLayer = CALayer()
        videoLayer.frame = frame
        animationLayer.addSublayer(videoLayer)
        
        // Make a sublayer for each animation
        for animationImageView in animationImageViews {
            guard let image = animationImageView.image?.cgImage else {
                print("Error: failed to get animation cgImage")
                return
            }
            
            let layer = CALayer()
            layer.frame = animationImageView.frame
            
            // Animate layer
            layer.contents = image
            setAnimation(layer)
            
            
            // Add the sublayer
            animationLayer.addSublayer(layer)
        }
        
        // Scale entire animation layer to fit the video
        // Calculate scale for mapping between onscreen and physical video
        let scaleX = renderRect.size.width / frame.width
        let scaleY = renderRect.size.height / frame.height
        animationLayer.setAffineTransform(CGAffineTransform(scaleX: scaleX, y: scaleY))
        // Reposition the animation layer to overlay correctly over video
        animationLayer.frame.origin = CGPoint(x: 0, y: 0)

        // Apply animation to video composition
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: animationLayer)
        
        // Export video with animation overlay
        guard let exporter = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error: failed to initialize exporter")
            return
        }
        exporter.videoComposition = videoComposition
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        try? FileManager.default.removeItem(at: outputURL)
        exporter.outputURL = outputURL
        exporter.exportAsynchronously {
            print("AVExporter Status: \(exporter.status.hashValue)")
            if let errorMessage = exporter.error?.localizedDescription {
                print("AVExport Errors: \(errorMessage)")
            }
            completion?()
        }
    }
}
