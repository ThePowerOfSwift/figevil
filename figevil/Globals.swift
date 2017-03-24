//
//  Globals.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

public let debug = true

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
