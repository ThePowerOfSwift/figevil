//
//  FirstTimeExperienceViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class FirstTimeExperienceViewController: UIViewController {

    @IBAction func tappedContinue(_ sender: Any) {
        let first = Storyboard.rootViewController
        
        present(first, animated: true) { 
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        AppDelegate.isFirstTimeLaunch = false
        // Do any additional setup after loading the view.
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
