//
//  CMSampleBuffer+CIImage.swift
//  figevil
//
//  Created by Satoru Sasozaki on 3/8/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import AVFoundation
import CoreImage

extension CMSampleBuffer {
    /** Make a brand new CIImage from CMSampleBuffer using bitmap. */
    var ciImage: CIImage? {
        get {
            // Get a CMSampleBuffer's Core Video image buffer for the media data
            guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(self) else {
                print("image buffer is nil")
                return nil
            }
            
            // Lock the base address of the pixel buffer
            CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
            
            // Get the number of bytes per row for the pixel buffer
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
            // Get the pixel buffer width and height
            
            let width = CVPixelBufferGetWidth(imageBuffer) // 1920
            let height = CVPixelBufferGetHeight(imageBuffer) // 1080
            
            // Create a device-dependent RGB color space
            let colorSpace = CGColorSpaceCreateDeviceRGB();
            
            // Create a bitmap graphics context with the sample buffer data
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little)
            guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
                print("Error creating context from cvpixelbuffer")
                return nil
            }
            
            // Create a Quartz image from the pixel data in the bitmap graphics context
            guard let quartzImage = context.makeImage() else {
                print("Error creating source image from quatz image")
                return nil
            }
            
            // Unlock the pixel buffer
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            let sourceImage = CIImage(cgImage: quartzImage)
            
            // resize
            //let scale = UIScreen.main.bounds.width / sourceImage.extent.width
            //sourceImage = sourceImage.applying(CGAffineTransform(scaleX: scale, y: scale)) // 251MB after snapping
            return sourceImage
        }
    }
}
