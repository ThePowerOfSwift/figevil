//
//  AppDelegate+FirstLaunch.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/17/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import AVFoundation

/// UserDefaults key to track FTE launch
public let kUserDefaultsFirstTimeLaunch = "isFirstTimeLaunch"

extension AppDelegate {
    /// Flag indicates whether the FTE has launched before
    class var isFirstTimeLaunch: Bool {
        get {
            if debug {
                return debug
            }
            return UserDefaults.standard.object(forKey: kUserDefaultsFirstTimeLaunch) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kUserDefaultsFirstTimeLaunch)
        }
    }
    
    /// First view controller (either root or FTE)
    var firstViewController: UIViewController {
        get {
            return AppDelegate.isFirstTimeLaunch ? Storyboard.FTEViewContoller : Storyboard.rootViewController
        }
    }
}
