//
//  FTECameraViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/5/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class FTECameraViewController: UIViewController, SatoCameraOutput {

    // Camera View
    let satoCamera: SatoCamera = SatoCamera.shared
    // MARK: SatoCameraOutput
    // Must always be behind all other views
    var sampleBufferView: UIView? = UIView()
    // Must always be on top of sampleBuffer
    var gifOutputView: UIView? = UIView()

    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupSatoCamera()
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
    
    func setupSatoCamera() {
        if let sampleBufferView = sampleBufferView {
            sampleBufferView.frame = view.bounds
            sampleBufferView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(sampleBufferView, at: 0)
        }
        
        if let gifOutputView = gifOutputView {
            gifOutputView.frame = view.bounds
            gifOutputView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(gifOutputView, at: 1)
        }
        
        satoCamera.cameraOutput = self
    }
}
