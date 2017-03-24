//
//  Gif.swift
//  LiveGifDemo
//
//  Created by Satoru Sasozaki on 3/1/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

// For saving gif to camera roll
//import ImageIO
//import MobileCoreServices
import Photos
import UIKit

class Gif: NSObject {
    var originalCIImages: [CIImage]

    /** Set 2 if you want to scale down to half of the original size. 
     Set 0 to keep the original size. */
    var scale: CGFloat
    /** frame for gif image view. */
    var frame: CGRect
    var filesize: Double = 0
    var filesizeString: String = "KB"
    var gifImageView: UIImageView?
    var filter: Filter?
    var preset: LiveGifPreset!
    
    init(originalCIImages: [CIImage], scale: CGFloat, frame: CGRect, filter: Filter?, preset: LiveGifPreset) {
        self.originalCIImages = originalCIImages
        self.scale = scale
        self.frame = frame
        self.filter = filter
        self.preset = preset
        super.init()
        process()
    }
    
    /** Produces a gif image view with specified settings*/
    func process() {
        var filteredCIImages = [CIImage]()
        if let filter = filter {
            filteredCIImages = filter.generateFilteredCIImages(sourceImages: originalCIImages)
        } else {
            filteredCIImages = originalCIImages
        }
        // fixOrientation
        guard let uiImages = createUIImages(from: filteredCIImages) else {
            print("rotated images is nil in \(#function)")
            return
        }
        
        gifImageView = createGifImageView(with: uiImages, frame: frame, duration: preset.liveGifDuration)

    }
    
    /** Fixes orientation of array of CIImage and apply filters to it.
     Fixing orientation and applying filter have to be done at the same time
     because fixing orientation only produces UIImage with its CIImage property nil.
     Scales down images.
     */
    func createUIImages(from ciImages: [CIImage]) -> [UIImage]? {
        var rotatedUIImages = [UIImage]()
        
        // whats the size of ciImages
        for ciImage in ciImages {
            
            //let uiImage = UIImage(ciImage: ciImage, scale: scale, orientation: UIImageOrientation.right) // 360, 640. The bigger scale is, the image smaller becomes
            let uiImage = UIImage(ciImage: ciImage)
            guard let rotatedImage = rotate(image: uiImage) else { // width: 1080, height: 1920, scale: 1.0, orientation: 0
                print("rotatedImage is nil in \(#function)")
                return nil
            }
            rotatedUIImages.append(rotatedImage)
        }
        
        return rotatedUIImages
    }
    
    /** Rotates image by 90 degrees. */
    func rotate(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContext(image.size)
//        guard let context = UIGraphicsGetCurrentContext() else {
//            print("context is nil in \(#function)")
//            return nil
//        }
        image.draw(at: CGPoint.zero)
        //context.rotate(by: CGFloat(M_PI_2)) // M_PI_2 = pi / 2 = 90 degrees (pi radians = 180 degrees)
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
    
    /** Saves output image to camera roll. */
    internal func save(drawImage: UIImage?, textImage: UIImage?, completion: ((_ saved: Bool, _ fileSize: String?) -> ())?) {
        // render gif
        guard let renderedGifImageView = render(drawImage: drawImage, textImage: textImage) else {
            print("rendered gif image view is nil")
            return
        }
        
        renderedGifImageView.saveGifToDisk(frameDelay: preset.frameDelay, completion: { (url: URL?, error: Error?) in
            if error != nil {
                print("\(error?.localizedDescription)")
            } else if let url = url {
                
                if let gifData = NSData(contentsOf: url) {
                    let gifSize = Double(gifData.length)
                    let gifSizeKB = gifSize / 1024.0
                    self.filesize = gifSizeKB
                    self.filesizeString = String(format: "%.2fKB", gifSizeKB)
                } else {
                    print("gif data is nil")
                }
                
                // check authorization status
                PHPhotoLibrary.requestAuthorization
                    { (status) -> Void in
                        switch (status)
                        {
                        case .authorized:
                            // Permission Granted
                        //print("Photo library usage authorized")
                        // save data to the url
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                        }, completionHandler: { (saved: Bool, error: Error?) in
                            if saved {
                                completion?(saved, self.filesizeString)
                            } else {
                                completion?(saved, nil)
                            }
                        })
                        case .denied:
                            // Permission Denied
                            print("User denied")
                        default:
                            print("Restricted")
                        }
                }
            }
        })
    }
    
    /** Renders drawings and texts into image. Needs to be saved to disk by save(completion:)*/
    internal func render(drawImage: UIImage?, textImage: UIImage?) -> UIImageView? {
        
        guard let gifImageView = gifImageView else {
            print("result imag view is nil")
            return nil
        }
        
        guard let animationImages = gifImageView.animationImages else {
            print("animation image is nil")
            return nil
        }
        
        var renderedAnimationImages = [UIImage]()
        
        // render draw and text into each animation image
        for animationImage in animationImages {
            UIGraphicsBeginImageContext(frame.size)
            // render here
            animationImage.draw(in: frame)
            drawImage?.draw(in: frame)
            textImage?.draw(in: frame)
            if let renderedAnimationImage = UIGraphicsGetImageFromCurrentImageContext() {
                renderedAnimationImages.append(renderedAnimationImage)
            } else {
                print("rendered animation image is nil")
            }
            UIGraphicsEndImageContext()
        }
        guard let renderedGifImageView = createGifImageView(with: renderedAnimationImages, frame: frame, duration: preset.liveGifDuration) else {
            print("rendered gif image view is nil in \(#function)")
            return nil
        }
        return renderedGifImageView
    }
    
    /** Generate animated image view with UIImages for gif. Call startAnimating() to play. */
    func createGifImageView(with images: [UIImage]?, frame: CGRect, duration: TimeInterval) -> UIImageView? {
        guard let images = images else {
            print("images are nil")
            return nil
        }
        
        let gifImageView = UIImageView()
        gifImageView.animationImages = images
        gifImageView.animationDuration = duration
        // repeat count 0 means infinite repeating
        gifImageView.animationRepeatCount = 0
        gifImageView.frame = frame
        return gifImageView
    }
}
