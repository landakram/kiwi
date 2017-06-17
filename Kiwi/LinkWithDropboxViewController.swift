//
//  ViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 2/24/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import MRProgress
import SwiftyDropbox
import RxSwift
import RxCocoa

class LinkWithDropboxViewController: UIViewController {
    @IBOutlet weak var linkWithDropboxButton: UIButton!
    var eventBus: EventBus = EventBus.sharedInstance
    var disposeBag: DisposeBag = DisposeBag()

    var upgradingFromV1: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true;
        
        linkWithDropboxButton.layer.borderWidth = 1
        linkWithDropboxButton.layer.cornerRadius = 5
        linkWithDropboxButton.layer.borderColor = Constants.KiwiColor.cgColor
        linkWithDropboxButton.layer.masksToBounds = true
        
        eventBus.accountLinkEvents.subscribe(onNext: { (event: AccountLinkEvent) in
            switch event {
            case .AccountLinked(_):
                self.maybeOpenWiki()
            }
        }).disposed(by: disposeBag)
        
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
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func maybeOpenWiki() {
        if let client = DropboxClientsManager.authorizedClient {
            let remote = DropboxRemote.sharedInstance
            
            let spinner = MRProgressOverlayView.showOverlayAdded(to: self.view.window,
                                                                 title: "Importing...",
                                                                 mode: .indeterminate,
                                                                 animated: true)
            spinner?.setTintColor(Constants.KiwiColor)
        
            let wiki = Wiki()
            wiki.scaffold()
            
            // Take the initial sync, and see if the changeset contains the home page
            let homeChangeset = remote.changesets
                .take(1)
                .filter({ (c: Changeset) -> Bool in
                return c.entries.filter({ $0.pathDisplay?.lastPathComponent == "home.md" }).count > 0
            })
            
            // If it does, then wait for it to sync
            homeChangeset.flatMap({ (c: Changeset) in
                return self.awaitHomeSync().filter({ $0.isRight() }).take(1)
            }).subscribe(onCompleted: {
                // And finally, move to the wiki view
                // We let the rest of the pages just download in the background.
                spinner?.dismiss(true)
                self.performSegue(withIdentifier: "LinkWithDropbox", sender: self)
            }).disposed(by: self.disposeBag)
            
            remote.configure(client: client)
            SyncEngine.sharedInstance.sweep()
        }
    }
    
    func awaitHomeSync(syncEngine: SyncEngine = SyncEngine.sharedInstance) -> Observable<Either<Progress, Path>> {
        return syncEngine.events.filter { (o: Operations) -> Bool in
            switch o {
            case .PullOperation(let operation):
                switch operation.event {
                case .write(let path):
                    return path.fileName == "home.md"
                default: return false
                }
            }
        }.flatMap({ (o: Operations) -> Observable<Either<Progress, Path>> in
            print("found home pull operation")
            switch o {
            case .PullOperation(let operation):
                return operation.stream
            }
        })
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

