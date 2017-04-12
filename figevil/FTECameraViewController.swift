//
//  FTECameraViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 4/5/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class FTECameraViewController: UIViewController, SatoCameraOutput {

    @IBOutlet weak var snapButton: UIButton!
    @IBOutlet weak var stickerLabel: UILabel!
    
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
    
    deinit {
        print("FTE camera controller deallocated")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.insertSubview(sampleBufferView!, at: 0)
        view.insertSubview(gifOutputView!, at: 1)
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
            view.addSubview(sampleBufferView)
        }
        
        if let gifOutputView = gifOutputView {
            gifOutputView.frame = view.bounds
            gifOutputView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(gifOutputView, at: 1)
        }
        
        satoCamera.cameraOutput = self
        satoCamera.toggleCamera()
    }

    var longPress: UILongPressGestureRecognizer?
    var cameraState = true
    @IBAction func tappedSnap(_ sender: Any) {
        if cameraState {
            satoCamera.snapLiveGif()
            
            snapButton.isHidden = true
            longPress = UILongPressGestureRecognizer(target: self, action: #selector(cancel(_:)))
            snapButton.addGestureRecognizer(longPress!)
            cameraState = false
        } else {
            // Render sticker
            UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0.0)
            stickerLabel.drawText(in: stickerLabel.frame)
            guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                print("Error: could not render sticker label")
                return
            }
            UIGraphicsEndImageContext()

            // Render gif and save it
            satoCamera.save(renderItems: [image], completion: { (success, urls, filesize) in })
        }
    }
    
    func didLiveGifStop() {
        snapButton.tintColor = UIColor.red
        snapButton.isHidden = false
        cameraState = false
    }
    
    func cancel(_ sender: UIGestureRecognizer) {
        satoCamera.reset()
        snapButton.isHidden = false
        snapButton.tintColor = UIColor.blue
        
        if let longPress = longPress {
            snapButton.removeGestureRecognizer(longPress)
        }
    }
}
