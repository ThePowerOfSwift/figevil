//
//  TextView.swift
//  BMe
//
//  Created by Jonathan Cheng on 2/22/17.
//  Copyright © 2017 Jonathan Cheng. All rights reserved.
//

import UIKit

private let defaultText = ":)"
private let defaultFont = UIFont(name: "Helvetica", size: 50)
private let defaultColor = UIColor.white
/** CGContext; Quality; 0.0 is screen resolution */
private let imageScale: CGFloat = 0.00

class TextView: UIView, UITextFieldDelegate {

    // Model
    /** The view that holds and draws the line */
    internal var imageView = UIImageView()
    
    // Text editing properties
    /** To store current font size for pinch gesture scaling */
    private var currentFontSize: CGFloat = 0
    /** The last rotation is the relative rotation value when rotation stopped last time,
     which indicates the current rotation */
    private var lastRotation: CGFloat = 0
    /** To store original center position for panned gesture */
    private var originalCenter: CGPoint?
    
    // Instance properties
    /** The current textField */
    var textField: UITextField?
    /** The current color */
    var color: UIColor = defaultColor {
        didSet {
            textField?.textColor = color
            textField?.attributedPlaceholder = attributedPlaceholder()
        }
    }
    
    /** Returns all the text fields */
    var textFields: [UITextField] {
        get {
            var textFields: [UITextField] = []
            for view in imageView.subviews {
                if let textField = view as? UITextField {
                    textFields.append(textField)
                }
            }
            return textFields
        }
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
    
    private func setup() {
        // Setup image view where draw actions are drawn
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedBackground(_:)))
        imageView.addGestureRecognizer(tap)
        imageView.isUserInteractionEnabled = true
        
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(imageView)
    }
    
    // MARK: TextField editing
    
    /** Add a text field to the screen and begin editing */
    func addTextfield() {
        // Create new textfield
        let newTextField = UITextField()
        self.textField = newTextField
        newTextField.delegate = self
        // Set newTextField behaviour
        newTextField.autocorrectionType = .no
        newTextField.autocapitalizationType = .sentences
        newTextField.spellCheckingType = .no
        newTextField.keyboardType = UIKeyboardType.asciiCapable
        newTextField.returnKeyType = .done
        newTextField.textColor = color
        newTextField.font = defaultFont
        
        // Lay gestures into created text field
        // Change
        newTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: UIControlEvents.editingChanged)
        // Double tap (to delete)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTappedTextField(_:)))
        tap.numberOfTapsRequired = 2
        newTextField.addGestureRecognizer(tap)
        // Pan (to move)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pannedTextField(_:)))
        newTextField.addGestureRecognizer(pan)
        
        // Pinch (to scale)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchedTextField(_:)))
        newTextField.addGestureRecognizer(pinch)
        
        // Rotation (to rotate)
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotatedTextField(_:)))
        newTextField.addGestureRecognizer(rotate)
        
        // Default appearance
        newTextField.attributedPlaceholder = attributedPlaceholder()
        newTextField.sizeToFit()
        
        // Add textField to view
        newTextField.center = imageView.center
        
        // Configure keyboard
        newTextField.keyboardType = UIKeyboardType.default
        
        // Add textfield to heirarchy
        imageView.addSubview(newTextField)
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            self.textField?.becomeFirstResponder()

//        }
    }
    
    func attributedPlaceholder() -> NSAttributedString? {
        return NSAttributedString(string: defaultText, attributes: [NSForegroundColorAttributeName: color])
    }
    
    private func removeAllTextfields() {
        for view in imageView.subviews {
            if let textField = view as? UITextField {
                textField.removeFromSuperview()
            }
        }
    }
    
    // MARK: Gesture responders
    
    /** On pinch, resize the textfield and it's contents */
    @objc private func pinchedTextField(_ sender: UIPinchGestureRecognizer) {
        if let textField = sender.view as? UITextField {
            if sender.state == .began {
                currentFontSize = textField.font!.pointSize
            } else if sender.state == .changed {
                textField.font = UIFont(name: textField.font!.fontName, size: currentFontSize * sender.scale)
                textFieldDidChange(textField)
            } else if sender.state == .ended {
                
            }
        }
    }
    
    /** Rotate the textfield and contents */
    @objc private func rotatedTextField(_ sender: UIRotationGestureRecognizer) {
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
    @objc private func doubleTappedTextField(_ sender: UITapGestureRecognizer) {
        let textField = sender.view
        textField?.removeFromSuperview()
    }
    
    /** On pan move the textfield */
    @objc private func pannedTextField(_ sender: UIPanGestureRecognizer) {
        
        if sender.state == UIGestureRecognizerState.began {
            originalCenter = sender.view!.center
        } else if sender.state == UIGestureRecognizerState.changed {
            
            let translation = sender.translation(in: imageView)
            sender.view?.center = CGPoint(x: originalCenter!.x + translation.x , y: originalCenter!.y + translation.y)
            
        } else if sender.state == UIGestureRecognizerState.ended {
            
        }
    }
    
    /** Tapped on background: end editing on all textfields */
    @objc fileprivate func tappedBackground(_ sender: UITapGestureRecognizer) {
        imageView.endEditing(true)
    }
    
    // MARK: Instance methods
    
    func reset() {
        imageView.removeFromSuperview()
        imageView = UIImageView()
        setup()
    }
    
    /** Render texts field into text image view. */
    func render() {
        
        // Configure context
        UIGraphicsBeginImageContextWithOptions(imageView.frame.size, false, imageScale)
//        imageView.image?.draw(in: imageView.frame)
        
        for textField in textFields {
            // Draw text in rect
//            let textLabelPointInImage = CGPoint(x: textField.frame.origin.x, y: textField.frame.origin.y)
//            let rect = CGRect(origin: textLabelPointInImage, size: imageView.frame.size)
//            textNSString.draw(in: rect, withAttributes: textFontAttributes)
            let rect = CGRect(origin: CGPoint(x: textField.frame.origin.x, y: textField.frame.origin.y), size: textField.frame.size)
            textField.drawText(in: rect)

        }
        
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    // MARK: UITextFieldDelegate
    
    /** Allow text fields to be edited */
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Set the current textfield
        self.textField = textField

        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
    
    /** On TextField change, resize the TextField */
    func textFieldDidChange(_ sender: UITextField) {
        sender.sizeToFit()
    }
}
