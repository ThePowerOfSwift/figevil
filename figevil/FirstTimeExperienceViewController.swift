//
//  FirstTimeExperienceViewController.swift
//  figevil
//
//  Created by Jonathan Cheng on 3/23/17.
//  Copyright © 2017 sunsethq. All rights reserved.
//

import UIKit

class FirstTimeExperienceViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!

    // Page View Controller
    var vcs: [UIViewController] = []
    @IBOutlet weak var pageViewContainer: UIView!
    let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal,
                                      options: [UIPageViewControllerOptionSpineLocationKey: UIPageViewControllerSpineLocation.max,
                                                UIPageViewControllerOptionInterPageSpacingKey: 0 as NSNumber])

    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        AppDelegate.isFirstTimeLaunch = false
        // Do any additional setup after loading the view.
        
        // Setup datasource
        pageVC.dataSource = self
        pageVC.delegate = self
        
        let storyboard = UIStoryboard(name: "FirstTimeExperience", bundle: nil)
        vcs.append(storyboard.instantiateViewController(withIdentifier: "FTEGetStartedViewController"))
        vcs.append(storyboard.instantiateViewController(withIdentifier: "FTECameraViewController"))

        // Setup page vc
        pageVC.setViewControllers([vcs.first!], direction: .forward, animated: true) { (success) in }
        pageVC.willMove(toParentViewController: self)
        pageVC.view.frame = pageViewContainer.bounds
        pageVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pageViewContainer.addSubview(pageVC.view)
        addChildViewController(pageVC)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Setup
    

    // MARK: UIPageViewControllerDataSource
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        if let idx = index(of: viewController) {
            let requested = idx + 1
            if (requested >= 0 && requested < vcs.count) {
                return vcs[requested]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let idx = index(of: viewController) {
            let requested = idx - 1
            if (requested >= 0 && requested < vcs.count) {
                return vcs[requested]
            }
        }
        return nil
    }
    
    func index(of viewController: UIViewController) -> Int? {
        guard let idx = vcs.index(of: viewController) else {
            return nil
        }
        return idx
    }
    
    // MARK: UIPageViewControllerDelegate
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        updateButtons(for: pendingViewControllers.first!)
    }
    
//    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
//    }
    
    func updateButtons(for viewController: UIViewController) {
        // Skip / End button
        skipButton.titleLabel?.text = viewController == vcs.last ? "End" : "Skip"
        nextButton.isHidden = viewController == vcs.last
    }
    
    // MARK: Actions
    
    @IBAction func tappedSkip(_ sender: Any) {
        present(Storyboard.rootViewController, animated: true) { }
    }
    
    @IBAction func tappedNext(_ sender: Any) {
        if let next = pageViewController(pageVC, viewControllerAfter: pageVC.viewControllers!.first!) {
            updateButtons(for: next)
            pageVC.setViewControllers([next], direction: .forward, animated: true, completion: { (success) in
            })
        }
        
    }

}
