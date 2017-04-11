//
//  FTIGetStartedViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/6/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit
import FLAnimatedImage

class FTEGetStartedViewController: UIViewController {

    @IBOutlet weak var animatedImageView: FLAnimatedImageView!
    @IBOutlet weak var animatedImageViewTopConstraint: NSLayoutConstraint!
    
    var loaded = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        
        loadGifData()
    }
    
    func loadGifData() {
        guard let url = Bundle.main.url(forResource: "selfie", withExtension: "gif") else {
            print("Error: did not find selfie gif in bundle")
            return
        }
        
        do {
            let selfieData = try Data(contentsOf: url)
            let gif = FLAnimatedImage(gifData: selfieData)
            animatedImageView.animatedImage = gif
            animatedImageView.startAnimating()
        } catch {
            print("Error: did not get selfie data")
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
