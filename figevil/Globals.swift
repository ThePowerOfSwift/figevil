//
//  Globals.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

let debug: Bool = false

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

enum UserGenerated {
    static let thumbnailTag = "@thumbnail"
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
