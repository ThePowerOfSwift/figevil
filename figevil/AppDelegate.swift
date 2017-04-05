//
//  AppDelegate.swift
//  figevil
//
//  Created by Jonathan Cheng on 2/27/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
//import Firebase
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        copyInBundleResources()
        
        // FIR Database setup
//        FIRApp.configure()
        
        // Set root VC
        window = UIWindow(frame: UIScreen.main.bounds)
        
        self.window?.rootViewController = firstViewController
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func copyInBundleResources() {
        if let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "Stickers") {            
            for url in urls {
                let filename = url.lastPathComponent
                guard let destination = UserGenerated.stickerDirectoryURL?.appendingPathComponent(filename) else {
                    print("Error: cannot get write-to URL for sticker \(filename)")
                    break
                }
                
                if !FileManager.default.fileExists(atPath: destination.path) {
                    do {
                        try FileManager.default.copyItem(at: url, to: destination)
                    } catch {
                        print("Error: failed copy item \(url.path)")
                    }
                }
            }
        } else {
            print("whoddunnit")
        }

    }

}

