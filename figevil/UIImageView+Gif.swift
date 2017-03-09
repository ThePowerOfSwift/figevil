//
//  UIImageView+Gif.swift
//  figevil
//
//  Created by Satoru Sasozaki on 3/8/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import CoreGraphics
import ImageIO
import MobileCoreServices

extension UIImageView {
    
    /** Creates gif data from [UIImage] and generate URL. */
    func saveGifToDisk(loopCount: Int = 0, frameDelay: Double , completion: (_ data: URL?, _ error: Error?) -> ()) {
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
