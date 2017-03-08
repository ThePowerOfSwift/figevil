//
//  Gif.swift
//  LiveGifDemo
//
//  Created by Satoru Sasozaki on 3/1/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

// For saving gif to camera roll
import ImageIO
import MobileCoreServices
import Photos
import UIKit

class Gif: NSObject {
    var originalCIImages: [CIImage]
    
    /** FPS for gif. real live preview FPS is 30. 5 should be */
    var currentGifFPS: Int
    var newGifFPS: Int
    var scale: Double
    var frame: CGRect
    var filesize: Double = 0
    var filesizeString: String = "KB"
    var gifImageView: UIImageView?
    var completion: ((Bool) -> ())?
    var filter: Filter?
    var gifPlayDuration: TimeInterval
    
    init(originalCIImages: [CIImage], currentGifFPS: Int, newGifFPS: Int,gifPlayDuration: TimeInterval = 1 , scale: Double, frame: CGRect, filter: Filter?) {
        self.originalCIImages = originalCIImages
        self.currentGifFPS = currentGifFPS
        self.newGifFPS = newGifFPS
        self.gifPlayDuration = gifPlayDuration
        self.scale = scale
        self.frame = frame
        self.filter = filter
        super.init()
        process()
    }
    
    /** Produces a gif image view with specified settings*/
    func process() {
        // getImagesWithNewFPS
        let imagesWithNewFPS = getImagesWithNewFPS(ciImages: originalCIImages)
        
        if let filteredCIImages = filter?.generateFilteredCIImages(sourceImages: imagesWithNewFPS) {
            // fixOrientation
            guard let rotatedUIImages = fixOrientation(ciImages: filteredCIImages) else {
                print("rotated images is nil in \(#function)")
                return
            }
            // createImagesIwthNewScale
            let scaledImages = createImagesWithNewScale(uiImages: rotatedUIImages, scale: scale)
            // generate gif
            gifImageView = UIImageView.generateGifImageView(with: scaledImages, frame: frame, duration: gifPlayDuration)
        } else {
        
            // fixOrientation
            guard let rotatedUIImages = fixOrientation(ciImages: imagesWithNewFPS) else {
                print("rotated images is nil in \(#function)")
                return
            }
            // createImagesIwthNewScale
            let scaledImages = createImagesWithNewScale(uiImages: rotatedUIImages, scale: scale)
            // generate gif
            gifImageView = UIImageView.generateGifImageView(with: scaledImages, frame: frame, duration: gifPlayDuration)
        }
    }
    
    func getImagesWithNewFPS(ciImages: [CIImage]) -> [CIImage] {
        var extractedCIImages = [CIImage]()
        
        let skipRate = currentGifFPS / newGifFPS // if gifFPS is 10 then skip rate is 3
        for i in 0..<ciImages.count {
            if i % skipRate == 0 {
                extractedCIImages.append(originalCIImages[i])
            }
        }
        return extractedCIImages
    }
    
    func createImagesWithNewScale(uiImages: [UIImage], scale: Double) -> [UIImage]? {
        return resizeUIImages(uiImages, scale: scale)
    }
    
    /** Fixes orientation of array of CIImage and apply filters to it.
     Fixing orientation and applying filter have to be done at the same time
     because fixing orientation only produces UIImage with its CIImage property nil.
     */
    func fixOrientation(ciImages: [CIImage]) -> [UIImage]? {
        var rotatedUIImages = [UIImage]()
        
        // whats the size of ciImages
        for ciImage in ciImages {
            
            let uiImage = UIImage(ciImage: ciImage, scale: 0, orientation: UIImageOrientation.right) // 360, 640. The bigger scale is, the image smaller becomes
            
            guard let rotatedImage = rotate(image: uiImage) else { // width: 1080, height: 1920, scale: 1.0, orientation: 0
                print("rotatedImage is nil in \(#function)")
                return nil
            }
            rotatedUIImages.append(rotatedImage)
        }
        
        return rotatedUIImages
    }

    /** Fixes orientation of CIImage and returns UIImage.
     Set orientation right or left and rotate it by 90 or -90 degrees to fix rotation. */
    func fixOrientation(ciImage: CIImage) -> UIImage? {
        // set orientation right or left and rotate it by 90 or -90 degrees to fix rotation
        let filteredUIImage = UIImage(ciImage: ciImage)
        guard let rotatedImage = rotate(image: filteredUIImage) else {
            print("rotatedImage is nil in \(#function)")
            return nil
        }
        
        return rotatedImage
// ---------------------------------------------------------------------------------------------
//        let filteredUIImage = UIImage(ciImage: ciImage, scale: 0, orientation: UIImageOrientation.left)
//        return filteredUIImage
    }
    
    /** Rotates image by 90 degrees. */
    func rotate(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContext(image.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("context is nil in \(#function)")
            return nil
        }
        image.draw(at: CGPoint.zero)
        //context.rotate(by: CGFloat(M_PI_2)) // M_PI_2 = pi / 2 = 90 degrees (pi radians = 180 degrees)
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
    
    func resizeUIImages(_ uiImages: [UIImage], scale: Double) -> [UIImage]? {
        var newImages = [UIImage]()
        for image in uiImages {
            if let newImage = resizeUIImage(image, scale: scale) {
                newImages.append(newImage)
            } else {
                print("resizeWithCGImage(uiImage:) returned nil")
            }
        }
        return newImages
    }
    
    func resizeUIImage(_ uiImage: UIImage, scale: Double) -> UIImage? {
        if scale == 0 {
            return uiImage
        } else {
            if let cgImage = uiImage.cgImage {
                let width: Int = Int(Double(frame.width) * scale)
                let height: Int = Int(Double(frame.height) * scale)
                let bitsPerComponent = cgImage.bitsPerComponent
                let bytesPerRow = cgImage.bytesPerRow
                let colorSpace = cgImage.colorSpace
                let bitmapInfo = cgImage.bitmapInfo
                
                let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue)
                
                context!.interpolationQuality = CGInterpolationQuality.low //.high
                
                context?.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
                
                let scaledImage = context!.makeImage().flatMap { UIImage(cgImage: $0) }
                //print("UIImage is resized: \(scaledImage?.size) in \(#function)")
                return scaledImage
            }
            print("cgimage from uiimage is nil in \(#function)")
        }
        return nil
    }
    
    /** Saves output image to camera roll. */
    internal func save(drawImage: UIImage?, textImage: UIImage?, completion: ((Bool) -> ())?) {
        // render gif
        guard let renderedGifImageView = render(drawImage: drawImage, textImage: textImage) else {
            print("rendered gif image view is nil")
            return
        }
        
        renderedGifImageView.saveGifToDisk(completion: { (url: URL?, error: Error?) in
            if error != nil {
                print("\(error?.localizedDescription)")
            } else if let url = url {
                
                if let gifData = NSData(contentsOf: url) {
                    let gifSize = Double(gifData.length)
                    let gifSizeKB = gifSize / 1024.0
                    print("size of gif in KB: ", gifSizeKB)
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
                                completion?(true)
                            } else {
                                completion?(false)
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
    
    // textImageView should render text fields into it
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
        // TODO: Replace 1 with gifPlayDuration
        guard let renderedGifImageView = UIImageView.generateGifImageView(with: renderedAnimationImages, frame: frame, duration: gifPlayDuration) else {
            print("rendered gif image view is nil in \(#function)")
            return nil
        }
        
        return renderedGifImageView
    }
    
}

extension UIImageView {
    // TODO: add method that plays gif in UIImageView https://github.com/bahlo/SwiftGif
    
    /** Generate animated image view with UIImages for gif. Call startAnimating() to play. */
    class func generateGifImageView(with images: [UIImage]?, frame: CGRect, duration: TimeInterval) -> UIImageView? {
        guard let images = images else {
            print("images are nil")
            return nil
        }
        
        let gifImageView = UIImageView()
        gifImageView.animationImages = images
        gifImageView.animationDuration = duration
        // repeat count 0 means infinite repeating
        gifImageView.animationRepeatCount = 0
        // images passed from didOutputSampleBuffer is landscape by default. so it has to be rotated by 90 degrees.
        //gifImageView.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
        gifImageView.frame = frame
        return gifImageView
    }
    
    /** Creates gif data from [UIImage] and generate URL. */
    func saveGifToDisk(loopCount: Int = 0, frameDelay: Double = 0, completion: (_ data: URL?, _ error: Error?) -> ()) {
        guard let animationImages = animationImages else {
            print("animation images is nil")
            return
        }
        if animationImages.isEmpty {
            print("animationImages is empty")
            return
        }
        
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: loopCount]]
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay]]
        let documentsDirectory = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: documentsDirectory).appendingPathComponent(getRandomGifFileName())
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeGIF, animationImages.count, nil) else {
            print("destination is nil")
            return
        }
        
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary?)
        
        for i in 0..<animationImages.count {
            CGImageDestinationAddImage(destination, animationImages[i].cgImage!, frameProperties as CFDictionary?)
        }
        
        if CGImageDestinationFinalize(destination) {
            completion(url, nil)
        } else {
            completion(nil, NSError())
        }
    }
    
    /** Creates gif name from time interval since 1970. */
    private func getRandomGifFileName() -> String {
        let gifName = String(Date().timeIntervalSince1970) + ".gif"
        return gifName
    }
}
