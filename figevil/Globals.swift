//
//  Globals.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

public let debug = true
/// Time for selection animation
public let selectionAnimationTime = 0.25
/// Application Group Identifier
public let applicationGroupIdentifier = "group.com.sunsethq.figevil"
/// URL for group container folder
public var groupContainerURL: URL? {
    get {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier)
    }
}
/// GIF file extension
public let gifFileExtension = "gif"
/// Directory to save user generated gifs
public let userGeneratedGifDirectory = "gifs"
/// URL for user generated gifs
public var userGeneratedGifURL: URL? {
    get {
        guard let url = groupContainerURL?.appendingPathComponent(userGeneratedGifDirectory, isDirectory: true) else {
            print("Error: Could not obtain URL for user GIF directory")
            return nil
        }
        
        // Create the diretory if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Error: Cannot create user directory for GIFs: \(error.localizedDescription)")
                return nil
            }
        }
        
        return url
    }
}

/// Storyboard constants
struct Storyboard {
    struct Names {
        static let Camera = "Camera"
        static let FTE = "FirstTimeExperience"
    }
 
    static var FTEViewContoller: UIViewController {
        get {
            let storyboard = UIStoryboard(name: Storyboard.Names.FTE, bundle: nil)
            assert((storyboard.instantiateInitialViewController() != nil), "FTE does not have an initial VC")
            return storyboard.instantiateInitialViewController()!
        }
    }
    
    static var rootViewController: UIViewController {
        get {
            let storyboard = UIStoryboard(name: Storyboard.Names.Camera, bundle: nil)
            assert((storyboard.instantiateInitialViewController() != nil), "Main view controller does not have an initial VC")
            return storyboard.instantiateInitialViewController()!

        }
    }
}
