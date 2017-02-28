//
//  DrawView.swift
//  effects
//
//  Created by Jonathan Cheng on 2/20/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

/** Draws a line to view following user touches */
class DrawView: UIView {
    
    /** The view that holds and draws the line */
    var imageView = UIImageView()
    /** Tracks the user's last touch point; used to draw lines between touch points */
    private var currentPoint = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var lastlastPoint = CGPoint.zero
    
    /** Quality; 0.0 is screen resolution */
    private var imageScale: CGFloat = 0.00
    
    /** The drawn line's width setting */
    var lineWidth: CGFloat = 7.0
    /** The drawn line's color setting */
    var currentColor: UIColor = UIColor.black
    
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
        // Setup image view where draw actions are drawn
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(imageView)
    }
    
    // MARK: Draw methods
    
    func reset() {
        imageView.removeFromSuperview()
        imageView = UIImageView()
        setup()
    }
    
    /** Starts a sequence of touches by the user */
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            // Initializes our point records to current location
            lastPoint = touch.previousLocation(in: self)
            lastlastPoint = touch.previousLocation(in: self)
            currentPoint = touch.previousLocation(in: self)
            
            // call touchesMoved:withEvent:, to possibly draw on zero movement
            touchesMoved(touches, with: event)
        }
    }
    
    /** Tracks user touches on the screen (like a drag) and draws a line between every two points */
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            
            // update points: previousPrevious -> mid1 -> previous -> mid2 -> current
            lastlastPoint = lastPoint
            lastPoint = touch.previousLocation(in: self)
            currentPoint = touch.location(in: self)
            
            let mid1: CGPoint = midPoint(p1: lastPoint, p2: lastlastPoint);
            let mid2: CGPoint = midPoint(p1: currentPoint, p2: lastPoint);
            
            // to represent the finger movement, create a new path segment,
            // a quadratic bezier path from mid1 to mid2, using previous as a control point
            let path = CGMutablePath()
            path.move(to: CGPoint(x: mid1.x, y: mid1.y))
            path.addQuadCurve(to: CGPoint(x: mid2.x, y: mid2.y), control: CGPoint(x: lastPoint.x, y: lastPoint.y))
            
            drawLine(path: path)
        }
    }
    
    /** Draw a line from one point to another on an image view */
    private func drawLine(path: CGMutablePath) {
        // Start a context with the size of vc view
        UIGraphicsBeginImageContextWithOptions(self.frame.size, false, imageScale)
        if let context = UIGraphicsGetCurrentContext() {
            // Draw previous contents (preserve)
            imageView.image?.draw(in: CGRect(x: 0, y: 0, width: imageView.frame.width, height: imageView.frame.size.height))
            
            // Add a line segment from lastPoint to currentPoint.
            context.addPath(path)
            
            // Setup draw settings
            context.setLineCap(CGLineCap.round)
            context.setLineWidth(lineWidth)
            context.setStrokeColor(currentColor.cgColor)
            context.setBlendMode(CGBlendMode.normal)
            
            // Draw the path
            context.strokePath()
            
            // Apply the path to drawingImageView
            imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
    }
    
    private func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        let point = CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
        return point
    }
    
}
