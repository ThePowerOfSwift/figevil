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

    @IBOutlet weak var selfieImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let gifAnimation = FLAnimatedImageView(frame: selfieImageView.frame)
        gifAnimation.contentMode = .bottom
        gifAnimation.clipsToBounds = true
        view.addSubview(gifAnimation)
        
        selfieImageView.removeFromSuperview()
        
        guard let url = Bundle.main.url(forResource: "selfie", withExtension: "gif") else {
            print("did not find selfie gif in bundle")
            return
        }
        
        do {
            let selfieData = try Data(contentsOf: url)
            let gif = FLAnimatedImage(gifData: selfieData)
            gifAnimation.animatedImage = gif
            gifAnimation.startAnimating()
        } catch {
            print("did not get selfie data")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
