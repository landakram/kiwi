//
//  ExternalLinkViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/10/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import WebKit

class ExternalLinkViewController: UIViewController {
    
    var url: NSURL!
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = WKWebViewConfiguration()
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView.allowsBackForwardNavigationGestures = true
//        self.webView.UIDelegate = self;
//        self.webView.navigationDelegate = self;
        self.view.addSubview(self.webView)
        
        var horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
            "H:|-0-[webView(view)]-0-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: ["webView": webView, "view": self.view])
        var verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
            "V:|-0-[webView(view)]-0-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: ["webView": webView, "view": self.view])
        
        self.view.addConstraints(horizontalConstraints)
        self.view.addConstraints(verticalConstraints)
        
        self.webView.loadRequest(NSURLRequest(URL: self.url))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
