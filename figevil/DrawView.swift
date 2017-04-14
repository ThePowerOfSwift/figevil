//
//  DrawView.swift
//  effects
//
//  Created by Jonathan Cheng on 2/20/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

/** Draws a line to view following user touches using Bezier paths */
class DrawView: UIView {

    private var lines = [Line]()
    private var finishedLines = [Line]()
    private let activeLine = NSMapTable<AnyObject, AnyObject>.strongToStrongObjects()
    
    /** The drawn line's color setting */
    var color: UIColor = UIColor.black
    
    /// A `CGContext` for drawing the last representation of lines no longer receiving updates into.
    lazy var frozenContext: CGContext = {
        let scale: CGFloat = self.window!.screen.scale
        var size = self.bounds.size
        
        size.width *= scale
        size.height *= scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        context!.concatenate(transform)
        
        return context!
    }()

    /// An `CGImage` containing the last representation of lines no longer receiving updates.
    var frozenImage: CGImage?
    
    var image: UIImage? {
        return (frozenImage != nil) ? UIImage(cgImage: frozenImage!) : nil
    }
    
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
        backgroundColor = UIColor.clear
    }
    
    // MARK: Draw methods
    
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
           
            if let frozenImage = frozenImage {
                context.draw(frozenImage, in: bounds)
            }
            
            for line in lines {
                line.drawInContext(context)
            }
        }
    }
    
    func drawTouch(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        var updateRect = CGRect.null
        
        for touch in touches {
            let line = activeLine.object(forKey: touch) as? Line ?? addNewLine(for: touch)
            let newRect = line.add(touch, with: color)
            updateRect = updateRect.union(newRect)
            
        }
        setNeedsDisplay(updateRect)
    }
    
    func addNewLine(for touch: UITouch) -> Line {
        let line = Line()
        lines.append(line)
        activeLine.setObject(line, forKey: touch)
        
        return line
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouch(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouch(touches, with: event)
    }
    
    /** Clears the context paths that will be drawn and provide to delegate the image that was drawn */
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // Line is no longer active
            // Add it to finished lines and remove from lines
            if let line = activeLine.object(forKey: touch) as? Line {
                freeze(line)
                
                // Remove the line from activity
                lines.remove(at: lines.index(of: line)!)
                activeLine.removeObject(forKey: touch)
            }
        }
    }
    
    func freeze(_ line: Line) {
        finishedLines.append(line)
        // Freeze the line (save)
        line.drawInContext(frozenContext)
        frozenImage = frozenContext.makeImage()
    }
    
    func undo() {
        if !finishedLines.isEmpty {
            frozenContext.clear(bounds)
            finishedLines.removeLast()
            
            for line in finishedLines {
                line.drawInContext(frozenContext)
            }
            
            frozenImage = frozenContext.makeImage()
            setNeedsDisplay()
        }
    }
    
    func reset() {
        lines.removeAll()
        activeLine.removeAllObjects()
        finishedLines.removeAll()
        frozenImage = nil
        frozenContext.clear(bounds)
        setNeedsDisplay()
    }
}


class Line: NSObject {
    /** Tracks the user's last touch point; used to draw lines between touch points */
    private var currentPoint: CGPoint?
    private var lastPoint: CGPoint?
    private var lastlastPoint: CGPoint?
    private var lastTimestamp: TimeInterval?
    private var currentTimestamp: TimeInterval?
    
    let defaultLineWidth: CGFloat = 5.0
    
    var linePaths = [LinePath]()
    
    override init() {
        super.init()
    }
    
    func add(_ touch: UITouch, with color: UIColor) -> CGRect{
        let view = touch.view
        lastlastPoint = lastPoint ?? touch.location(in: view)
        lastPoint = touch.previousLocation(in: view)
        currentPoint = touch.location(in: view)
        lastTimestamp = currentTimestamp ?? touch.timestamp
        currentTimestamp = touch.timestamp
        
        // Calculate the mid points to construct a Bezier path
        let mid1: CGPoint = midPoint(p1: lastPoint!, p2: lastlastPoint!);
        let mid2: CGPoint = midPoint(p1: currentPoint!, p2: lastPoint!);

        // Create a quadratic bezier path from mid1 to mid2, using previous as a control point
        let path = CGMutablePath()
        path.move(to: CGPoint(x: mid1.x, y: mid1.y))
        path.addQuadCurve(to: CGPoint(x: mid2.x, y: mid2.y), control: CGPoint(x: lastPoint!.x, y: lastPoint!.y))

        // Calculate line thickness with force touch, or speed (if not avail)
        var lineWidth: CGFloat
        if (view?.traitCollection.forceTouchCapability == .available) {
            lineWidth = max(touch.force * defaultLineWidth, 0.01)
        } else {
            // Calculate velocity
            // pts / second
            let dx = CGFloat(currentPoint!.x - lastPoint!.x)
            let dy = CGFloat(currentPoint!.y - lastPoint!.y)
            let dTime = CGFloat((lastTimestamp! - currentTimestamp!).truncatingRemainder(dividingBy: 60))
            
            let velocityX: CGFloat = dTime.isNaN || dTime == 0 ? 0.0 : (dx / dTime)
            let velocityY: CGFloat = dTime.isNaN || dTime == 0 ? 0.0 : (dy / dTime)
            
            var summSq: Float = Float(pow(velocityX, 2)) + Float(pow(velocityY, 2))
            summSq = summSq == 0 ? 0.1 : summSq.squareRoot()
            
            let multiplier: Float = 2.0
            let base: Float = 5.0
            var adjusted: Float = base - (log2f(summSq) / multiplier)
            adjusted = min(max(adjusted, 0.4), base)
            
            lineWidth = CGFloat(  adjusted * Float(defaultLineWidth))
        }
        
        let linepath = LinePath(path, color: color, lineWidth: lineWidth)
        linePaths.append(linepath)
        
        let magnitude: CGFloat = -lineWidth * 2.0
        return path.boundingBoxOfPath.insetBy(dx: magnitude, dy: magnitude)
    }
    
    func drawInContext(_ context: CGContext) {
        context.setLineCap(CGLineCap.round)
        context.setBlendMode(CGBlendMode.normal)

        for linepath in linePaths {
            context.setLineWidth(linepath.lineWidth)
            context.setStrokeColor(linepath.color.cgColor)
            context.addPath(linepath.path)
            context.strokePath()
        }
    }
    
    /** Returns the midpoint between two points */
    private func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        let point = CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
        return point
    }
}

class LinePath: NSObject {
    var path = CGMutablePath()
    var color = UIColor()
    var lineWidth: CGFloat = 0.0
    
    override init() {
        super.init()
    }
    
    convenience init(_ path: CGMutablePath, color: UIColor, lineWidth: CGFloat) {
        self.init()
        self.path = path
        self.color = color
        self.lineWidth = lineWidth
    }
}
