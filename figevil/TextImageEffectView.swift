//
//  TextImageEffectView.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/22/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

class TextImageEffectView: UIView, CameraViewBubbleMenu {

    /** Model */
    var textView = TextView()
    
    // MARK: CameraViewBubbleMenu
    var menuContent: [BubbleMenuCollectionViewCellContent] = []
    var iconContent = BubbleMenuCollectionViewCellContent(image: UIImage(named: "montgomery.jpg")!, label: "Text")
    var showsMenuContentOnKeyboard: Bool = true
    
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
        setupBubbleMenuContent()
    }
    
    func setupTextView() {
        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(textView)
    }
    
    func setupBubbleMenuContent() {
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
            menuContent.append(bubble)
        }
    }
    
    // MARK: CameraViewBubbleMenu
    
    func menu(_ sender: BubbleMenuCollectionViewController, didSelectItemAt indexPath: IndexPath) {
        textView.color = Color.list()[indexPath.row].uiColor
    }
    
    func didSelect(_ sender: CameraViewBubbleMenu) {
        textView.addTextfield()
    }
    
    func reset() {
        textView.reset()
    }
}
