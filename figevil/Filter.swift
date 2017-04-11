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
    var iconImage = UIImage()
    
    var list = [Filter]()
    
    static let filterBubbleIconImage = UIImage(named: BubbleIcon.filter)
    var context = CIContext()

    static let shared: Filter = Filter()
    
    override init() {
        self.name = "shared"
        self.filter = nil
        self.imageUrlString = nil
        super.init()
        configureList()
    }
    
    init(name: String, filter: CIFilter?) {
        self.name = name
        self.filter = filter
        super.init()
        self.iconImage = getIconImage(filter: filter)
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
        list.append(plain)
        list.append(sepiaTone)
        list.append(falseColor)
        list.append(photoEffectChrome)
        list.append(photoEffectFade)
        list.append(photoEffectInstant)
        list.append(photoEffectMono)
        list.append(photoEffectNoir)
        list.append(photoEffectProcess)
        list.append(photoEffectTonal)
        list.append(photoEffectTransfer)
        list.append(colorClamp)
        list.append(unsharpMask)
        list.append(comicEffect)
        list.append(crystallize)
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
    
    var plain: Filter {
        return Filter(name: "Plain", filter: nil)
    }
    
    // MARK: Photo Effect
    
    var sepiaTone: Filter {
        let filter = CIFilter(name: "CISepiaTone")
        return Filter(name: "Sepia", filter: filter)
    }
    
    var falseColor: Filter {
        let filter = CIFilter(name: "CIFalseColor")
        return Filter(name: "False", filter: filter)
    }
    
    var colorClamp: Filter {
        let filter = CIFilter(name: "CIColorClamp")
        let n: CGFloat = 0.05
        let minComp = CIVector(x: n, y: n, z: n, w: 1)
        let maxComp = CIVector(x: 1, y: 1, z: 1, w: 1)
        filter?.setValue(minComp, forKeyPath: "inputMinComponents")
        filter?.setValue(maxComp, forKeyPath: "inputMaxComponents")
        return Filter(name: "colorClamp", filter: filter)
    }
    
    var photoEffectChrome: Filter {
        let filter = CIFilter(name: "CIPhotoEffectChrome")
        return Filter(name: "photoEffectChrome", filter: filter)
    }
    
    var photoEffectFade: Filter {
        let filter = CIFilter(name: "CIPhotoEffectFade")
        return Filter(name: "photoEffectFade", filter: filter)
    }
    
    var photoEffectInstant: Filter {
        let filter = CIFilter(name: "CIPhotoEffectInstant")
        return Filter(name: "photoEffectInstant", filter: filter)
    }
    
    var photoEffectMono: Filter {
        let filter = CIFilter(name: "CIPhotoEffectMono")
        return Filter(name: "photoEffectMono", filter: filter)
    }
    
    var photoEffectNoir: Filter {
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        return Filter(name: "photoEffectNoir", filter: filter)
    }
    
    var photoEffectProcess: Filter {
        let filter = CIFilter(name: "CIPhotoEffectProcess")
        return Filter(name: "photoEffectProcess", filter: filter)
    }
    
    var photoEffectTonal: Filter {
        let filter = CIFilter(name: "CIPhotoEffectTonal")
        return Filter(name: "photoEffectTonal", filter: filter)
    }
    
    var photoEffectTransfer: Filter {
        let filter = CIFilter(name: "CIPhotoEffectTransfer")
        return Filter(name: "photoEffectTransfer", filter: filter)
    }
    
    var vignetteEffect: Filter {
        let filter = CIFilter(name: "CIVignetteEffect")
        return Filter(name: "vegnetteEffect", filter: filter)
    }

    // MARK: CICategoryColorEffect
    
    var colorControls: Filter {
        let filter = CIFilter(name: "CIColorControls")
        return Filter(name: "colorControls", filter: filter)
    }
    
    var colorMatrix: Filter {
        let filter = CIFilter(name: "CIColorMatrix")
        return Filter(name: "colorMatrix", filter: filter)
    }
    
    var colorPolynomial: Filter {
        let filter = CIFilter(name: "CIColorPolynomial")
        return Filter(name: "colorPolynomial", filter: filter)
    }
    
    var colorCrossPolynomial: Filter {
        let filter = CIFilter(name: "CIColorCrossPolynomial")
        return Filter(name: "colorCrossPolynomial", filter: filter)
    }
    
    var colorCube: Filter {
        let filter = CIFilter(name: "CIColorCube")
        return Filter(name: "colorCube", filter: filter)
    }

    var colorCubeWithColorSpace: Filter {
        let filter = CIFilter(name: "CIColorCubeWithColorSpace")
        return Filter(name: "colorCubeWithColorSpace", filter: filter)
    }
    
    var colorInvert: Filter {
        let filter = CIFilter(name: "CIColorInvert")
        return Filter(name: "colorInvert", filter: filter)
    }
    
    var colorMap: Filter {
        let filter = CIFilter(name: "CIColorMap")
        return Filter(name: "colorMap", filter: filter)
    }
    
    var colorMonochrome: Filter {
        let filter = CIFilter(name: "CIColorMonochrome")
        return Filter(name: "colorMonochrome", filter: filter)
    }
    
    var colorPosterize: Filter {
        let filter = CIFilter(name: "CIColorPosterize")
        return Filter(name: "colorPosterize", filter: filter)
    }
    
    // MARK: Sharpen
    var unsharpMask: Filter {
        let filter = CIFilter(name: "CIUnsharpMask")
        return Filter(name: "unsharpMask", filter: filter)
    }
    
    // MARK: CICategoryStylize
    var comicEffect: Filter {
        let filter = CIFilter(name: "CIComicEffect")
        return Filter(name: "comicEffect", filter: filter)
    }
    
    var crystallize: Filter {
        let filter = CIFilter(name: "CICrystallize")
        return Filter(name: "crystallize", filter: filter)
    }
    
    var edges: Filter {
        let filter = CIFilter(name: "CIEdges")
        return Filter(name: "edges", filter: filter)
    }
    
    var edgeWork: Filter {
        let filter = CIFilter(name: "CIEdgeWork")
        return Filter(name: "edgeWork", filter: filter)
    }
    
    var gloom: Filter {
        let filter = CIFilter(name: "CIGloom")
        return Filter(name: "gloom", filter: filter)
    }
    
    var highlightShadowAdjus: Filter {
        let filter = CIFilter(name: "CIHighlightShadowAdjus")
        return Filter(name: "highlightShadowAdjus", filter: filter)
    }
    
    var lineOverlay: Filter {
        let filter = CIFilter(name: "CILineOverlay")
        return Filter(name: "lineOverlay", filter: filter)
    }
    
    var pixellate: Filter {
        let filter = CIFilter(name: "CIPixellate")
        return Filter(name: "pixellate", filter: filter)
    }
    
    var pointillize: Filter {
        let filter = CIFilter(name: "CIPointillize")
        return Filter(name: "pointillize", filter: filter)
    }
    
    // MARK: CICategoryTileEffect
    
    /** Need to adjust to make it work correctly.*/
    var kaleidoscope: Filter {
        let filter = CIFilter(name: "CIKaleidoscope")
        return Filter(name: "kaleidoscope", filter: filter)
    }
    
    /** Need to adjust to make it work correctly.*/
    var parallelogramTile: Filter {
        let filter = CIFilter(name: "CIParallelogramTile")
        return Filter(name: "parallelogramTile", filter: filter)
    }

}
