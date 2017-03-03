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
    
    func generateFilteredCIImages(sourceImages: [CIImage]) -> [CIImage]? {
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
                Filter(name: "Plain", filter: nil, imageUrlString: "chinatown.jpg"),
                Filter(name: "Sepia", filter: CIFilter(name: "CISepiaTone"), imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "False", filter: CIFilter(name: "CIFalseColor"), imageUrlString: "chinatown.jpg"),
                Filter(name: "Plain", filter: nil, imageUrlString: "chinatown.jpg"),
                Filter(name: "Sepia", filter: CIFilter(name: "CISepiaTone"), imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "False", filter: CIFilter(name: "CIFalseColor"), imageUrlString: "chinatown.jpg"),
                Filter(name: "Plain", filter: nil, imageUrlString: "chinatown.jpg"),
                Filter(name: "Sepia", filter: CIFilter(name: "CISepiaTone"), imageUrlString: "golden_gate_bridge.jpg"),
                Filter(name: "False", filter: CIFilter(name: "CIFalseColor"), imageUrlString: "chinatown.jpg")
        ]
    }
}
