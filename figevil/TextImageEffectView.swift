//
//  TextImageEffectView.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/22/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

class TextImageEffectView: UIView, CameraEffect {

    /** Model */
    var textView = TextView()
    
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
        setupTextView()
    }
    
    func setupTextView() {
        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(textView)
    }
    
    // MARK: CameraEffect
    
    var iconImage: UIImage {
        return #imageLiteral(resourceName: "text")
    }
    var label: String {
        return "Text"
    }

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
    
    var showsMenuContentOnKeyboard: Bool = true
        
    func didSelectPrimaryMenuItem(_ atIndex: Int) {
        textView.color = Color.list()[atIndex].uiColor
    }
    
    func isSelected() {
        textView.addTextfield()
    }
    
    func reset() {
        textView.reset()
    }
}
