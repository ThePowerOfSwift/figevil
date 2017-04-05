//  Filter.swift
//
//  Created by Satoru Sasozaki on 1/29/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

import UIKit

class Filter: NSObject {
    var name: String
    var filter: CIFilter?
    var imageUrlString: String

    init(name: String, filter: CIFilter?, imageUrlString: String) {
        self.name = name
        self.filter = filter
        self.imageUrlString = imageUrlString
    }

    func generateFilteredCIImage(sourceImage: CIImage) -> CIImage? {
        if let filter = filter {
            filter.setValue(sourceImage, forKey: kCIInputImageKey)
            return filter.outputImage
        } else {
            return sourceImage
        }
    }
    
    func generateFilteredCIImages(sourceImages: [CIImage]) -> [CIImage] {
        var filteredCIImages = [CIImage]()
        for sourceImage in sourceImages {
            if let filter = filter {
                filter.setValue(sourceImage, forKey: kCIInputImageKey)
                //return filter.outputImage
                if let filteredCIImage = filter.outputImage {
                    filteredCIImages.append(filteredCIImage)
                } else {
                    print("filetered CIImage is nil in \(#function)")
                }
            } else {
                filteredCIImages.append(sourceImage)
            }
        }
        return filteredCIImages
    }

    class func list() -> [Filter] {
        // Double size for testing
        return [Filter(name: "Plain", filter: nil, imageUrlString: "chinatown.jpg"),
                Filter(name: "Sepia", filter: CIFilter(name: "CISepiaTone"), imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "False", filter: CIFilter(name: "CIFalseColor"), imageUrlString: "chinatown.jpg"),
                Filter(name: "EffectChrome", filter: photoEffectChrome, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectFade", filter: photoEffectFade, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectInstant", filter: photoEffectInstant, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectMono", filter: photoEffectMono, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectNoir", filter: photoEffectNoir, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectProcess", filter: photoEffectProcess, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectTonal", filter: photoEffectTonal, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "EffectTransfer", filter: photoEffectTransfer, imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "Clamp", filter: colorClamp, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Controls", filter: colorControls, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Matrix", filter: colorMatrix, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Polynomial", filter: colorPolynomial, imageUrlString: "chinatown.jpg"),
//                Filter(name: "CrossPolynomial", filter: colorCrossPolynomial, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Cube", filter: colorCube, imageUrlString: "chinatown.jpg"),
//                Filter(name: "CubeWithColorSpace", filter: colorCubeWithColorSpace, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Invert", filter: colorInvert, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Map", filter: colorMap, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Monochrome", filter: colorMonochrome, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Posterize", filter: colorPosterize, imageUrlString: "chinatown.jpg"),
//                Filter(name: "Vignette", filter: vignetteEffect, imageUrlString: "golden_gate_bridge.jpg")

        ]
    }
    
    class var colorClamp: CIFilter? {
        let filter = CIFilter(name: "CIColorClamp")
        let n: CGFloat = 0.05
        let minComp = CIVector(x: n, y: n, z: n, w: 1)
        let maxComp = CIVector(x: 1, y: 1, z: 1, w: 1)
        filter?.setValue(minComp, forKeyPath: "inputMinComponents")
        filter?.setValue(maxComp, forKeyPath: "inputMaxComponents")
        return filter
    }
    
    class var colorControls: CIFilter? {
        let filter = CIFilter(name: "CIColorControls")
        
        return filter
    }
    
    class var colorMatrix: CIFilter? {
        let filter = CIFilter(name: "CIColorMatrix")
        return filter
    }
    
    class var colorPolynomial: CIFilter? {
        let filter = CIFilter(name: "CIColorPolynomial")
        return filter
    }
    
    // MARK: CICategoryColorEffect
    
    class var colorCrossPolynomial: CIFilter? {
        let filter = CIFilter(name: "CIColorCrossPolynomial")
        return filter
    }
    
    class var colorCube: CIFilter? {
        let filter = CIFilter(name: "CIColorCube")

        return filter
    }


    
    class var colorCubeWithColorSpace: CIFilter? {
        let filter = CIFilter(name: "CIColorCubeWithColorSpace")
        return filter
    }
    
    class var colorInvert: CIFilter? {
        let filter = CIFilter(name: "CIColorInvert")
        return filter
    }
    
    class var colorMap: CIFilter? {
        let filter = CIFilter(name: "CIColorMap")
        return filter
    }
    
    class var colorMonochrome: CIFilter? {
        let filter = CIFilter(name: "CIColorMonochrome")
        return filter
    }
    
    class var colorPosterize: CIFilter? {
        let filter = CIFilter(name: "CIColorPosterize")
        return filter
    }
    
    class var photoEffectChrome: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectChrome")
        
        return filter
    }
    
    class var photoEffectFade: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectFade")
        return filter
    }
    
    class var photoEffectInstant: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectInstant")
        return filter
    }
    
    class var photoEffectMono: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectMono")
        return filter
    }
    
    class var photoEffectNoir: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        return filter
    }
    
    class var photoEffectProcess: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectProcess")
        return filter
    }
    
    class var photoEffectTonal: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectTonal")
        return filter
    }
    
    class var photoEffectTransfer: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectTransfer")
        return filter
    }
    
    class var vignetteEffect: CIFilter? {
        let filter = CIFilter(name: "CIVignetteEffect")
        return filter
    }
    
    
    
}
