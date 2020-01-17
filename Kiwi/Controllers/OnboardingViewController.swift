//
//  OnboardingViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 1/16/20.
//  Copyright © 2020 Mark Hudnall. All rights reserved.
//

import UIKit

class OnboardingViewController: UIViewController {
    @IBOutlet weak var getStartedButton: UIButton!
    
    var upgradingFromV1: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true;

        getStartedButton.layer.borderWidth = 1
        getStartedButton.layer.cornerRadius = 5
        getStartedButton.layer.borderColor = Constants.KiwiColor.cgColor
        getStartedButton.layer.masksToBounds = true
        
        if upgradingFromV1 {
            let path = Bundle.main.path(forResource: "update_notes_2.0.0", ofType: "md")
            let content = try! String(contentsOf: URL(fileURLWithPath: path!), encoding: .utf8)
            
            let page = Page(rawContent: content , permalink: "update_notes_2.0.0", name: "Update Notes", modifiedTime: Date(), createdTime: Date(), isDirty: false)
            
            let wikiController = UpdateNotesViewController(nibName: "UpdateNotesViewController", bundle: nil)
            wikiController.page = page
            
            let navigation = UINavigationController(rootViewController: wikiController)
            self.present(navigation, animated: true, completion: nil)
        }
    }
    

    @IBAction func didPressGetStarted(_ sender: UIButton) {
        self.performSegue(withIdentifier: "GetStarted", sender: self)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
