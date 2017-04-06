//  Filter.swift
//
//  Created by Satoru Sasozaki on 1/29/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

import UIKit

class Filter: NSObject {
    var name: String
    var filter: CIFilter?
    var imageUrlString: String?
    var iconImage: UIImage
    
    var list = [Filter]()
    static let filterBubbleIconImage = UIImage(named: BubbleIcon.filter)
    var context = CIContext()

    static let shared: Filter = Filter()
    
    override init() {
        self.name = "shared"
        self.filter = nil
        self.imageUrlString = nil
        self.iconImage = UIImage()
        super.init()
        configureList()
    }

    init(name: String, filter: CIFilter?, imageUrlString: String) {
        self.name = name
        self.filter = filter
        self.imageUrlString = imageUrlString
        if let image = UIImage(named: imageUrlString) {
            self.iconImage = image
        } else {
            self.iconImage = UIImage()
        }
    }
    
    init(name: String, filter: CIFilter?, iconImage: UIImage) {
        self.name = name
        self.filter = filter
        self.iconImage = iconImage
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
    
    func configureList() {
        list.append(Filter(name: "Plain", filter: nil, iconImage: getIconImage(filter: nil)))
        list.append(Filter(name: "Sepia", filter: CIFilter(name: "CISepiaTone"), iconImage: getIconImage(filter: CIFilter(name: "CISepiaTone"))))
        list.append(Filter(name: "False", filter: CIFilter(name: "CIFalseColor"), iconImage: getIconImage(filter: CIFilter(name: "CIFalseColor"))))
        list.append(Filter(name: "EffectChrome", filter: photoEffectChrome, iconImage: getIconImage(filter: photoEffectChrome)))
        list.append(Filter(name: "EffectFade", filter: photoEffectFade, iconImage: getIconImage(filter: photoEffectFade)))
        list.append(Filter(name: "EffectInstant", filter: photoEffectInstant, iconImage: getIconImage(filter: photoEffectInstant)))
        list.append(Filter(name: "EffectMono", filter: photoEffectMono, iconImage: getIconImage(filter: photoEffectMono)))
        list.append(Filter(name: "EffectNoir", filter: photoEffectNoir, iconImage: getIconImage(filter: photoEffectNoir)))
        list.append(Filter(name: "EffectProcess", filter: photoEffectProcess, iconImage: getIconImage(filter: photoEffectProcess)))
        list.append(Filter(name: "EffectTonal", filter: photoEffectTonal, iconImage: getIconImage(filter: photoEffectTonal)))
        list.append(Filter(name: "EffectTransfer", filter: photoEffectTransfer, iconImage: getIconImage(filter: photoEffectTransfer)))
        list.append(Filter(name: "Clamp", filter: colorClamp, iconImage: getIconImage(filter: colorClamp)))
    }

    func getIconImage(filter: CIFilter?) -> UIImage {
        if let sourceImage = Filter.filterBubbleIconImage {
            if let ciImage = CIImage(image: sourceImage) {
                var outputUIImage = UIImage()
                if let filter = filter {
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    if let filteredImage = filter.outputImage {
                        if let cgImage = context.createCGImage(filteredImage, from: ciImage.extent) {
                            outputUIImage = UIImage(cgImage: cgImage)
                        } else {
                            outputUIImage = sourceImage
                            print("Error: failed to get cgImage in \(#function)")
                        }
                        
                    } else {
                        print("Error: failed to produce outputImage with the filter in \(#function)")
                    }
                } else {
                    outputUIImage = UIImage(ciImage: ciImage)
                }
                return outputUIImage
            }
        }
        print("Error: failed to get icon image in \(#function)")
        return UIImage()
    }
    
    // MARK: Photo Effect
    
    var colorClamp: CIFilter? {
        let filter = CIFilter(name: "CIColorClamp")
        let n: CGFloat = 0.05
        let minComp = CIVector(x: n, y: n, z: n, w: 1)
        let maxComp = CIVector(x: 1, y: 1, z: 1, w: 1)
        filter?.setValue(minComp, forKeyPath: "inputMinComponents")
        filter?.setValue(maxComp, forKeyPath: "inputMaxComponents")
        return filter
    }
    
    var photoEffectChrome: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectChrome")
        
        return filter
    }
    
    var photoEffectFade: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectFade")
        return filter
    }
    
    var photoEffectInstant: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectInstant")
        return filter
    }
    
    var photoEffectMono: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectMono")
        return filter
    }
    
    var photoEffectNoir: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        return filter
    }
    
    var photoEffectProcess: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectProcess")
        return filter
    }
    
    var photoEffectTonal: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectTonal")
        return filter
    }
    
    var photoEffectTransfer: CIFilter? {
        let filter = CIFilter(name: "CIPhotoEffectTransfer")
        return filter
    }
    
    class var vignetteEffect: CIFilter? {
        let filter = CIFilter(name: "CIVignetteEffect")
        return filter
    }

    // MARK: CICategoryColorEffect
    
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
}
