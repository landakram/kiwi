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
import SwiftyDropbox
import EmitterKit
import BrightFutures
import Result

class LinkWithDropboxViewController: UIViewController {
    @IBOutlet weak var linkWithDropboxButton: UIButton!
    var eventBus: EventBus = EventBus.sharedInstance
    var listener: EventListener<AccountLinkEvent>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true;
        
        linkWithDropboxButton.layer.borderWidth = 1
        linkWithDropboxButton.layer.cornerRadius = 5
        linkWithDropboxButton.layer.borderColor = Constants.KiwiColor.cgColor
        linkWithDropboxButton.layer.masksToBounds = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.listener.isListening = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.maybeOpenWiki()
        
        self.listener = eventBus.accountLinkEvents.on { (event: AccountLinkEvent) in
            switch event {
            case .AccountLinked(_):
                self.maybeOpenWiki()
            }
        }
    }
    
    func maybeOpenWiki() {
        if let client = DropboxClientsManager.authorizedClient {
            let remote = DropboxRemote.sharedInstance
            remote.configure(client: client)
            
            let spinner = MRProgressOverlayView.showOverlayAdded(to: self.view.window,
                                                                 title: "Importing...",
                                                                 mode: .indeterminate,
                                                                 animated: true)
            spinner?.setTintColor(Constants.KiwiColor)
            
            
            remote.start().onSuccess {
                let wiki = Wiki()
                wiki.scaffold()
                spinner?.dismiss(true)
                self.performSegue(withIdentifier: "LinkWithDropbox", sender: self)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPressLinkWithDropbox(_ sender: AnyObject) {
        DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: { (url: URL) in
            UIApplication.shared.openURL(url);
        })
    }

}

