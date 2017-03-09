//
//  CVPixelBuffer+DeepCopy.swift
//  figevil
//
//  Created by Satoru Sasozaki on 3/8/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import CoreVideo

// https://gist.github.com/valkjsaaa/f9edfc25b4fd592caf82834fafc07759
extension CVPixelBuffer {
    /** Make a deep copy of CVPixelBuffer. */
    func deepcopy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional:CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, format, nil, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags.readOnly)
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        }
        return pixelBufferCopyOptional
    }
}
