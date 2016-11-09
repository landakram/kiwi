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
        
        self.navigationController?.isNavigationBarHidden = true;
        
        linkWithDropboxButton.layer.borderWidth = 1
        linkWithDropboxButton.layer.cornerRadius = 5
        linkWithDropboxButton.layer.borderColor = Constants.KiwiColor.cgColor
        linkWithDropboxButton.layer.masksToBounds = true
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPressLinkWithDropbox(_ sender: AnyObject) {
        DBAccountManager.shared().addObserver(self, block: {
            (account: DBAccount?) in
            guard let account = account else { return }
            if account.isLinked {
                DBAccountManager.shared().removeObserver(self)
                if DBFilesystem.shared() == nil {
                    let filesystem = DBFilesystem(account: account)
                    DBFilesystem.setShared(filesystem)
                }
                if !DBFilesystem.shared().completedFirstSync {
                    let spinner = MRProgressOverlayView.showOverlayAdded(to: self.view.window,
                        title: "Importing...",
                        mode: .indeterminate,
                        animated: true)
                    spinner?.setTintColor(Constants.KiwiColor)
                    DBFilesystem.shared().addObserver(self, block: { () -> Void in
                        if DBFilesystem.shared().completedFirstSync {
                            DBFilesystem.shared().removeObserver(self)
                            
                            // Load the whole wiki from Dropbox, then move on
                            let wiki = Wiki()
                            Async.background {
                                if let fileInfos = DropboxRemote.sharedInstance.getAllFileInfos() {
                                    let total = Float(fileInfos.count)
                                    for (index, info) in fileInfos.enumerated() {
                                        if let file = DBFilesystem.shared().openFile(info.path, error: nil) {
                                            var error: DBError?
                                            file.readData(&error)
                                        }
                                        if index == 0 {
                                            Async.main {
                                                spinner?.mode = .determinateCircular;
                                            }
                                        }
                                        Async.main {
                                            spinner?.setProgress(Float(index + 1) / total, animated: true)
                                        }
                                    }
                                }
                            }.main {
                                spinner?.mode = .indeterminate
                            }.background {_ in
                                DropboxRemote.sharedInstance.configure(filesystem: DBFilesystem.shared())
                                DropboxRemote.sharedInstance.start()
//                                wiki.syncUpdatedPagesToYapDatabase()
                            }.main {
                                spinner?.dismiss(true)
                                
                                self.performSegue(withIdentifier: "LinkWithDropbox", sender: self)
                            }
                        }
                    })
                } else {
                    self.performSegue(withIdentifier: "LinkWithDropbox", sender: self)
                }
            }
        })
        DBAccountManager.shared().link(from: self)
    }

}

