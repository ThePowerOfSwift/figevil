//
//  FirstTimeExperienceViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class FirstTimeExperienceViewController: UIViewController, SatoCameraOutput {

    var satoCamera: SatoCamera = SatoCamera.shared
    // MARK: SatoCameraOutput
    // Must always be behind all other views
    var sampleBufferView: UIView? = UIView()
    // Must always be on top of sampleBuffer
    var outputImageView: UIImageView? = UIImageView()

    
    @IBAction func tappedContinue(_ sender: Any) {
        let first = Storyboard.rootViewController
        
        present(first, animated: true) { 
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        AppDelegate.isFirstTimeLaunch = false
        // Do any additional setup after loading the view.
        
        
        // SatoCamera setup
        if let sampleBufferView = sampleBufferView {
            sampleBufferView.frame = view.bounds
            sampleBufferView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(sampleBufferView, at: 0)
        }
        
        if let outputImageView = outputImageView {
            outputImageView.frame = view.bounds
            outputImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(outputImageView, at: 1)
        }
        
        satoCamera.cameraOutput = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        satoCamera.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        satoCamera.stop()
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
