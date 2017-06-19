//
//  UpdateNotesViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 5/29/17.
//  Copyright © 2017 Mark Hudnall. All rights reserved.
//

import UIKit

class UpdateNotesViewController: WikiViewController {

    var page: Page!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
        doneButton.rx.tap.subscribe(onNext: { (_) in
            self.dismiss(animated: true, completion: nil)
        }).disposed(by: self.disposeBag)
        self.navigationItem.rightBarButtonItem = doneButton
        
        self.renderPage(self.page)
        self.titleView.isUserInteractionEnabled = false
    }
    
    override func setUpWiki() {
        self.wiki = Wiki()
        self.wiki.writeResouceFiles()
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
