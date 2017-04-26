//
//  DrawImageEffectViewController.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/20/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

class DrawImageEffectView: UIView, CameraEffect {
    
    /** Model */
    var drawView = DrawView()
    
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
        setupDrawView()
    }
    
    func setupDrawView() {
        drawView.frame = bounds
        drawView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(drawView)
    }
    
    // MARK: CameraEffect
    
    var primaryMenu: [BubbleMenuCollectionViewCellContent] {
        var menu: [BubbleMenuCollectionViewCellContent] = []
        // Create color images and bubble contents for each color in list
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        for color in Color.list() {
            // Create an image with the color
            UIGraphicsBeginImageContext(rect.size)
            
            guard let context = UIGraphicsGetCurrentContext() else {
                print("Error: cannot get graphics context to create color image")
                UIGraphicsEndImageContext()
                break
            }
            context.setFillColor(color.cgColor)
            context.fill(rect)
            guard let colorImage = UIGraphicsGetImageFromCurrentImageContext() else {
                print("Error: cannot get color image from context")
                UIGraphicsEndImageContext()
                break
            }
            UIGraphicsEndImageContext()
            
            let bubble = BubbleMenuCollectionViewCellContent(image: colorImage, label: color.name)
            menu.append(bubble)
        }
        return menu
    }
    
    func didSelectPrimaryMenuItem(_ atIndex: Int) {
        drawView.color = Color.list()[atIndex].uiColor
    }
        
    func reset() {
        drawView.reset()
    }
}
