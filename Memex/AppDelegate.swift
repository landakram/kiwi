//
//  AppDelegate.swift
//  Memex
//
//  Created by Mark Hudnall on 2/24/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit    

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        let accountManager = DBAccountManager(appKey: "***REMOVED***", secret: "***REMOVED***")
        DBAccountManager.setSharedManager(accountManager)
        
        if let account = DBAccountManager.sharedManager().linkedAccount {
            if account.linked {
                if DBFilesystem.sharedFilesystem() == nil {
                    let filesystem = DBFilesystem(account: account)
                    DBFilesystem.setSharedFilesystem(filesystem)
                }
                let rootViewController = self.window?.rootViewController?.storyboard?.instantiateViewControllerWithIdentifier("WikiViewControllerIdentifier") as? UIViewController
                (self.window?.rootViewController as UINavigationController).setViewControllers([rootViewController!], animated: false)
            }
        }
        UINavigationBar.appearance().tintColor = UIColor(red: 0.362, green: 0.724, blue: 0.111, alpha: 1.0)
        UINavigationBar.appearance().titleTextAttributes = [
            NSForegroundColorAttributeName: UINavigationBar.appearance().tintColor,
//            UITextAttributeTextShadowColor: [UIColor colorWithRed:0.362 green:0.724 blue:0.111 alpha:0.8],
//            UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, -1)],
            NSFontAttributeName: UIFont.systemFontOfSize(0),
        ]
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        let account = DBAccountManager.sharedManager().handleOpenURL(url)
        if (account != nil) {
            println("App linked successfully!")
            return true
        }
        
        return false
    }


}

