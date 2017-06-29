//
//  AppDelegate.swift
//  Kiwi
//
//  Created by Mark Hudnall on 2/24/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import FileKit
import SwiftyDropbox
import AMScrollingNavbar
import YapDatabase
import RxSwift
import SwiftMessages
import ReachabilitySwift
import RxReachability

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    var filesystem: Filesystem = Filesystem.sharedInstance
    var syncEngine: SyncEngine = SyncEngine.sharedInstance
    var indexer: Indexer = Indexer.sharedInstance
    
    var disposeBag: DisposeBag = DisposeBag()
    
    var reachability: Reachability?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        Fabric.with([Crashlytics.self])
        
        DropboxClientsManager.setupWithAppKey(DropboxAppKey)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let rootNavigationController = storyboard.instantiateViewController(withIdentifier: "RootNavigationController") as? ScrollingNavigationController
        
        let didDeleteApp = DropboxClientsManager.authorizedClient != nil && self.isLoadingForFirstTime()
        if didDeleteApp {
            DropboxClientsManager.unlinkClients()
        }
        if let client = DropboxClientsManager.authorizedClient {
            syncEngine.remote.configure(client: client)
            
            self.syncEngine.sweep()
            
            reachability = Reachability()
            try? reachability?.startNotifier()
            reachability?.rx.isConnected
                .subscribe(onNext: {
                    self.syncEngine.sweep()
                })
                .addDisposableTo(disposeBag)
            
            let rootViewController = storyboard.instantiateViewController(withIdentifier: "WikiViewControllerIdentifier") as? WikiViewController
            rootNavigationController?.viewControllers = [rootViewController!]
        } else if self.isUpdating() {
            let conn = Yap.sharedInstance.newConnection()
            conn.readWrite({ (t: YapDatabaseReadWriteTransaction) in
                t.removeAllObjectsInAllCollections()
            })
            
            let rootViewController = storyboard.instantiateViewController(withIdentifier: "LinkWithDropboxIdentifier") as? LinkWithDropboxViewController
            rootViewController?.upgradingFromV1 = true
            rootNavigationController?.viewControllers = [rootViewController!]
        } else {
            let rootViewController = storyboard.instantiateViewController(withIdentifier: "LinkWithDropboxIdentifier") as? LinkWithDropboxViewController
            rootNavigationController?.viewControllers = [rootViewController!]
        }
        
        let deadlineTime = DispatchTime.now() + .seconds(3)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self.markVersion()
        }
        
        setUpStatusBarMessages()
        
        self.window?.rootViewController = rootNavigationController
        self.window?.makeKeyAndVisible()
        let kiwiColor = Constants.KiwiColor
        UIToolbar.appearance().tintColor = kiwiColor
        UINavigationBar.appearance().tintColor = kiwiColor
        UISearchBar.appearance().tintColor = kiwiColor
        UITextField.appearance().tintColor = kiwiColor
        UITextView.appearance().tintColor = kiwiColor
        UINavigationBar.appearance().titleTextAttributes = [
            NSForegroundColorAttributeName: UINavigationBar.appearance().tintColor,
            NSFontAttributeName: UIFont.systemFont(ofSize: 0),
        ]
        
        return true
    }
    
    func setUpStatusBarMessages() {
        let view = MessageView.viewFromNib(layout: .StatusLine)
        var config = SwiftMessages.Config()
        config.presentationContext = .window(windowLevel: UIWindowLevelStatusBar)
        config.duration = .indefinite(delay: 0, minimum: 1)
        
        var lastPushFilename: String? = nil
        var lastPullFilename: String? = nil
        self.syncEngine.events.subscribe(onNext: { (o: Operations) in
            switch o {
            case .PullOperation(let operation):
                switch operation.event {
                case .write(let path):
                    let filename = path.fileName
                    lastPullFilename = filename
                    operation.stream.subscribe(onNext: { (e: Either<Progress, Path>) in
                        switch e {
                        case .left( _):
                            // When a file is pushed, it is then pulled right after.
                            // This not-so-gracefully prevents ths subsequent pull message 
                            // from showing
                            if lastPushFilename != filename {
                                view.configureContent(body: "Downloading \(filename)...")
                                SwiftMessages.show(config: config, view: view)
                            }
                        case .right( _): break
                        }
                        
                        // Reset the lastPullFilename after a few seconds
                        // This way, we still show notifications if a remote
                        // file is changed repeatedly.
                        let deadlineTime = DispatchTime.now() + .seconds(3)
                        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                            if lastPullFilename == filename {
                                lastPullFilename = nil
                            }
                        }

                    }, onCompleted: { 
                        SwiftMessages.hide(id: view.id)
                    }).disposed(by: self.disposeBag)
                default: break
                }
            case .PushOperation(let operation):
                switch operation.event {
                case .write(let path):
                    let filename = path.fileName
                    lastPushFilename = filename
                    operation.stream.subscribe(onNext: { (e: Either<Progress, Path>) in
                        switch e {
                        case .left(_):
                            if lastPullFilename != filename {
                                view.configureContent(body: "Uploading \(filename)...")
                                SwiftMessages.show(config: config, view: view)
                            }
                        case .right(_): break
                        }
                        
                        let deadlineTime = DispatchTime.now() + .seconds(3)
                        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                            if lastPushFilename == filename {
                                lastPushFilename = nil
                            }
                        }
                    }, onCompleted: {
                        SwiftMessages.hide(id: view.id)
                    }).disposed(by: self.disposeBag)
                default: break
                }
            }
        }).disposed(by: self.disposeBag)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        if let client = DropboxClientsManager.authorizedClient {
            syncEngine.remote.configure(client: client)
            self.syncEngine.sweep()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        if let authResult = DropboxClientsManager.handleRedirectURL(url) {
            switch authResult {
            case .success:
                print("Success! User is logged into Dropbox.")
            case .cancel:
                print("Authorization flow was manually canceled by user!")
            case .error(_, let description):
                print("Error: \(description)")
            }
            
            EventBus.sharedInstance.publish(event: .AccountLinked(authResult: authResult))
        }
        
        return true
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        if self.isUpdating() || self.isLoadingForFirstTime() {
            print("Not restoring state")
            return false
        }
        print("Restoring state")
        return true
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    
    func isLoadingForFirstTime() -> Bool {
        return !UserDefaults.standard.bool(forKey: "didLoadFirstTime")
    }
    
    func markVersion() {
        let defaults = UserDefaults.standard
        let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        defaults.set(currentAppVersion, forKey: "appVersion")
    }
    
    func isUpdating() -> Bool {
        let defaults = UserDefaults.standard
        
        let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let previousVersion = defaults.string(forKey: "appVersion")
        if previousVersion == nil && self.isLoadingForFirstTime() {
            // first launch
            return false
        } else if previousVersion == nil && !self.isLoadingForFirstTime() {
            // First time setting the app version
            return true
        }
        else if previousVersion == currentAppVersion {
            // same version
            return false
        } else {
            // other version
            return true
        }
    }
}

