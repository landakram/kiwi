//
//  ViewController.swift
//  Memex
//
//  Created by Mark Hudnall on 2/24/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit

class LinkWithDropboxViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPressLinkWithDropbox(sender: AnyObject) {
        DBAccountManager.sharedManager().addObserver(self, block: {
            (account: DBAccount!) in
            if account.linked {
                DBAccountManager.sharedManager().removeObserver(self)
                if DBFilesystem.sharedFilesystem() == nil {
                    let filesystem = DBFilesystem(account: account)
                    DBFilesystem.setSharedFilesystem(filesystem)
                }
                if !DBFilesystem.sharedFilesystem().completedFirstSync {
                    DBFilesystem.sharedFilesystem().addObserver(self, block: { () -> Void in
                        if DBFilesystem.sharedFilesystem().completedFirstSync {
                            DBFilesystem.sharedFilesystem().removeObserver(self)
                            self.performSegueWithIdentifier("LinkWithDropbox", sender: self)
                        }
                    })
                } else {
                    self.performSegueWithIdentifier("LinkWithDropbox", sender: self)
                }
            }
        })
        DBAccountManager.sharedManager().linkFromController(self)
    }

}

