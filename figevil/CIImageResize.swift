//
//  CIImage+Resize.swift
//  figevil
//
//  Created by Satoru Sasozaki on 3/8/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import CoreImage

extension CIImage {
    
    /** Resize CIImage using CIContext. Worst performance according to NSHipster. http://nshipster.com/image-resizing/. */
    func resizeWithCIContext(frame: CGRect) -> CIImage? {
        /*print("BEFORE scaled CIImage extent: \(self.extent) in \(#function)")
        
        let scale = frame.width / self.extent.width
        
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(self, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        guard let outputImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else {
            print("output image is nil in \(#function)")
            return nil
        }
        
        let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
        
        guard let scaledCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            print("scaled CGImage is nil in \(#function)")
            return nil
        }
        
        // code below is not being executed. Execution stops the line above.
        let scaledCIImage = CIImage(cgImage: scaledCGImage)
        print("AFTER scaled CIImage extent: \(scaledCIImage.extent) in \(#function)")
        
        return scaledCIImage*/ return nil
    }
    
    /** Resize CIImage using CGContext. if CIImage is created from sample buffer, CGImage is nil. */
    func resizeWithCGContext(frame: CGRect) -> CIImage? {
        
        /*
        // https://developer.apple.com/reference/coreimage/ciimage/1687603-cgimage
        // If CIImage is created from init(cgImage:) or init(contentsOf:) initializer, cgImage property is value
        // otherwise nil. In that case, to create CGImage from CIImage, use CIContext createCGImage(_:from:)
        
        // CGImage is nil
        guard let cgImage = self.cgImage else {
            print("CGImage from CIImage is nil")
            return nil
        }
        
        let width = cgImage.width / 2
        let height = cgImage.height / 2
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace
        let bitmapInfo = cgImage.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) else {
            print("context is nil in \(#function)")
            return nil
        }
        
        context.interpolationQuality = CGInterpolationQuality.high
        
        context.draw(cgImage, in:  CGRect(origin: CGPoint.zero, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
        guard let scaledCGImage = context.makeImage() else {
            print("newCGImage is nil in \(#function)")
            return nil
        }
        
        let scaledCIImage = CIImage(cgImage: scaledCGImage)
        return scaledCIImage*/
        return nil
    }
}
