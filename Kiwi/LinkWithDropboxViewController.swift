//
//  ViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 2/24/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import MRProgress
import Async

class LinkWithDropboxViewController: UIViewController {
    @IBOutlet weak var linkWithDropboxButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBarHidden = true;
        
        linkWithDropboxButton.layer.borderWidth = 1
        linkWithDropboxButton.layer.cornerRadius = 5
        linkWithDropboxButton.layer.borderColor = Constants.KiwiColor.CGColor
        linkWithDropboxButton.layer.masksToBounds = true
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
                    let spinner = MRProgressOverlayView.showOverlayAddedTo(self.view.window,
                        title: "Importing...",
                        mode: .Indeterminate,
                        animated: true)
                    spinner.setTintColor(Constants.KiwiColor)
                    DBFilesystem.sharedFilesystem().addObserver(self, block: { () -> Void in
                        if DBFilesystem.sharedFilesystem().completedFirstSync {
                            DBFilesystem.sharedFilesystem().removeObserver(self)
                            
                            // Load the whole wiki from Dropbox, then move on
                            let wiki = Wiki()
                            Async.background {
                                if let fileInfos = wiki.getAllFileInfos() {
                                    let total = Float(fileInfos.count)
                                    for (index, info) in enumerate(fileInfos) {
                                        if let file = DBFilesystem.sharedFilesystem().openFile(info.path, error: nil) {
                                            var error: DBError?
                                            file.readData(&error)
                                        }
                                        if index == 0 {
                                            Async.main {
                                                spinner.mode = .DeterminateCircular;
                                            }
                                        }
                                        Async.main {
                                            spinner.setProgress(Float(index + 1) / total, animated: true)
                                        }
                                    }
                                }
                            }.main {
                                spinner.mode = .Indeterminate
                            }.background {
                                wiki.syncUpdatedPagesToYapDatabase()
                            }.main {
                                spinner.dismiss(true)
                                self.performSegueWithIdentifier("LinkWithDropbox", sender: self)
                            }
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

