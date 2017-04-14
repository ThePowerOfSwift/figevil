//
//  AnimationView.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/12/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import AVFoundation
import Lottie

class AnimationView: UIView {
    
    // MARK: Model
    var animationViews: [LOTAnimationView] = []
    
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
        
        guard let animationView = LOTAnimationView(contentsOf: url) else {
            print("Error: Cannot load Lottie animation for \(url.path)")
            return
        }
        animationView.contentMode = .scaleAspectFit
        animationView.frame.size = Sizes.minimumGestureManipulation
        animationView.center = center
        // Let the clear background recieve gestures
        animationView.backgroundColor = UIColor.lightGray.withAlphaComponent(Numbers.tiny)
        addGestures(animationView)
        
        addSubview(animationView)
        animationViews.append(animationView)
        animationView.play()
        animationView.loopAnimation = true
    }
    
    func addGestures(_ view: UIView) {
        // Gestures
        view.isUserInteractionEnabled = true
        // Double tap (to delete)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)
        // Pan (to move)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        view.addGestureRecognizer(pan)
        // Pinch (to scale)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        view.addGestureRecognizer(pinch)
        // Rotation (to rotate)
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:)))
        view.addGestureRecognizer(rotate)
    }
    
    // MARK: Gestures
    /// The last rotation is the relative rotation value when rotation stopped last time, which indicates the current rotation
    private var lastRotation: CGFloat = 0
    /// To store original center position for panned gesture
    private var originalCenter: CGPoint?

    /// On pan move the view
    @objc private func panned(_ sender: UIPanGestureRecognizer) {
        guard let view = sender.view else {
            print("Error: could not get view for panning")
            return
        }
        
        if sender.state == .began || sender.state == .changed {
            let translation = sender.translation(in: view)
            view.transform = view.transform.translatedBy(x: translation.x, y: translation.y)
            sender.setTranslation(CGPoint.zero, in: view)
        }
    }

    /// Rotate
    @objc private func rotated(_ sender: UIRotationGestureRecognizer) {
        if sender.state == .began || sender.state == .changed {
            guard let view = sender.view else {
                print("Error: Could not get view to rotate")
                return
            }
            view.transform = view.transform.rotated(by: sender.rotation)
            sender.rotation = 0.0
        }
    }
    
    /// On double tap remove
    @objc private func doubleTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view  else {
            print("Error: did not find animation view to remove")
            return
        }
        guard let index = animationViews.index(of: view as! LOTAnimationView) else {
            print("Error: did not find animation view in animations array")
            return
        }
        view.removeFromSuperview()
        animationViews.remove(at: index)
    }
    
    /// On pinch, resize
    @objc private func pinched(_ sender: UIPinchGestureRecognizer) {
        guard let view = sender.view else {
            print("Error: failed to get animation view to resize")
            return
        }
        
        if sender.state == .changed || sender.state == .ended {
            let scale = sender.scale
            view.transform = view.transform.scaledBy(x: scale, y: scale)
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
        if animationLayer.contentsAreFlipped() {
            animationLayer.isGeometryFlipped = true
        }
        
        // Set video layer as "backing" layer (to be overlaid on)
        let videoLayer = CALayer()
        videoLayer.frame = frame
        animationLayer.addSublayer(videoLayer)
        
        // Make a sublayer for each animation
        for animationView in animationViews {
            animationLayer.addSublayer(animationView.layer)
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
