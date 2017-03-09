//
//  LiveGifPreset.swift
//  figevil
//
//  Created by Satoru Sasozaki on 3/8/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import Foundation

struct LiveGifPreset {
    /** has to be 0 < gifFPS <= 15 and 30 */
    var gifFPS: Int
    var liveGifDuration: TimeInterval
    
    var frameCaptureFrequency: Int {
        return Int(sampleBufferFPS) / gifFPS
    }
    var sampleBufferFPS: Int32 = 30
    var liveGifFrameTotalCount: Int {
        return Int(liveGifDuration * Double(gifFPS))
    }
    
    /** The amount of time each frame stays. */
    var frameDelay: Double {
        return Double(liveGifDuration) / Double(liveGifFrameTotalCount)
    }
    
    init(gifFPS: Int, liveGifDuration: TimeInterval) {
        self.gifFPS = gifFPS
        self.liveGifDuration = liveGifDuration
    }
}
