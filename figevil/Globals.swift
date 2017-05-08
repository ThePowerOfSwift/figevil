//
//  Globals.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

let debug: Bool = false
let debugCameraOff: Bool = false

enum Camera {
    enum screen {
        case fullscreen
        case square
        
        func size() -> CGSize {
            var size = CGSize.zero
            
            switch self {
            case .fullscreen:
                size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            case .square:
                size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
            }
            
            return size
        }
        
        mutating func toggle() {
            self = self == .fullscreen ? .square : .fullscreen
        }
    }
    
    enum liveGifPreset {
        static let sampleBufferFPS = 30
        static let gifFPS = 10
        static let gifDuration = 2
    }
    
    enum pixelsize {
        static let message = 350
        static let thumbnail = 245
    }
}

var Autokey: String {
    return String(Date().timeIntervalSinceReferenceDate) + UUID().uuidString
}

enum Sizes {
    static let minimumTappable = CGSize(width: 44.0, height: 44.0)
    static let minimumGestureManipulation = CGSize(width: 90.0, height: 90.0)
}

enum Numbers {
    static let tiny: CGFloat = 0.001
}

enum FileExtension {
    static let movie: String = ".m4v"
    static let gif: String = ".gif"
}

/// Time Internals for animation
enum AnimationTime {
    static let select = 0.25 / 2
    static let deselect = 0.25
    static let fadeout = 3.5
}

enum ApplicationGroup {
    static let identifier = "group.com.sunsethq.figevil"
    /// URL for group container folder
    static let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ApplicationGroup.identifier)
}

enum BubbleIcon {
    static let filter = "ice_cream_cone.png"
}

enum UserGenerated {
    static let thumbnailTag = "@thumbnail"
    static let messageTag = "@message"
    static let originalTag = "@original"
    /// URL for user generated gifsg
    static var gifDirectoryURL: URL? {
        guard let url = ApplicationGroup.containerURL?.appendingPathComponent("gifs", isDirectory: true) else {
            print("Error: Could not obtain container URL for user generated GIF")
            return nil
        }
        
        // Create the diretory if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Error: Cannot create directory for user GIFs: \(error.localizedDescription)")
                return nil
            }
        }
        return url
    }
    
    static var stickerDirectoryURL: URL? {
        guard let url = ApplicationGroup.containerURL?.appendingPathComponent("stickers", isDirectory: true) else {
            print("Error: Could not obtain container URL for user stickers")
            return nil
        }
        
        // Create the diretory if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Error: Cannot create directory for user stickers: \(error.localizedDescription)")
                return nil
            }
        }
        return url
    }
}

/// Storyboard constants
enum Storyboard {
    enum Names {
        static let Camera = "Camera"
        static let FTE = "FirstTimeExperience"
    }
 
    static var FTEViewContoller: UIViewController {
        let storyboard = UIStoryboard(name: Storyboard.Names.FTE, bundle: nil)
        assert((storyboard.instantiateInitialViewController() != nil), "FTE does not have an initial VC")
        return storyboard.instantiateInitialViewController()!
    }
    
    static var rootViewController: UIViewController {
        let storyboard = UIStoryboard(name: Storyboard.Names.Camera, bundle: nil)
        assert((storyboard.instantiateInitialViewController() != nil), "Main view controller does not have an initial VC")
        return storyboard.instantiateInitialViewController()!
    }
}
