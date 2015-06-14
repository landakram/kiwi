//
//  WikiViewController.swift
//  Memex
//
//  Created by Mark Hudnall on 3/5/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import WebKit
import GRMustache
import IDMPhotoBrowser
import STKWebKitViewController

class WikiViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var webViewContainer: UIView!
    var webView: WKWebView!
    var wiki: Wiki!
    var currentPage: Page!
    
    var pendingPageName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupWebView()
        
        self.wiki = Wiki()
        
        
        let scriptPath = NSBundle.mainBundle().pathForResource("links", ofType: "js")!
        let stylesPath = NSBundle.mainBundle().pathForResource("screen", ofType: "css")!
        self.wiki.copyFileToLocal(scriptPath)
        self.wiki.copyFileToLocal(NSBundle.mainBundle().pathForResource("auto-render-latex.min", ofType: "js")!)
        self.wiki.copyFileToLocal(NSBundle.mainBundle().pathForResource("prism", ofType: "css")!)
        self.wiki.copyFileToLocal(NSBundle.mainBundle().pathForResource("prism", ofType: "js")!)
        
        self.wiki.copyFileToLocal(stylesPath)
        
        self.renderPermalink("home")
//        self.followScrollView(self.webView, usingTopConstraint: self.topConstraint, withDelay: 0.75)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Mark: - Setup
    
    func setupWebView() {
        let userContentController = WKUserContentController()
        let handler = NavigationScriptMessageHandler(delegate: self)
        userContentController.addScriptMessageHandler(handler, name: NavigationScriptMessageHandler.name)
        let imageHandler = ImageBrowserScriptHandler(delegate: self)
        userContentController.addScriptMessageHandler(imageHandler, name: ImageBrowserScriptHandler.name)
        let checklistHandler = ChecklistScriptMessageHandler(delegate: self)
        userContentController.addScriptMessageHandler(checklistHandler, name: ChecklistScriptMessageHandler.name)
        userContentController.addScriptMessageHandler(checklistHandler, name: "loaded")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        self.webView.restorationIdentifier = "WikiWebView"
        self.webView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.UIDelegate = self;
        self.webView.navigationDelegate = self;
        self.webViewContainer.addSubview(self.webView)
        
        var horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
            "H:|-0-[webView(webViewContainer)]-0-|",
            options: NSLayoutFormatOptions(0),
            metrics: nil,
            views: ["webView": webView, "webViewContainer": webViewContainer])
        var verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
            "V:|-0-[webView(webViewContainer)]-0-|",
            options: NSLayoutFormatOptions(0),
            metrics: nil,
            views: ["webView": webView, "webViewContainer": webViewContainer])
        
        webViewContainer.addConstraints(horizontalConstraints)
        webViewContainer.addConstraints(verticalConstraints)
        
        var swipeGesture = UISwipeGestureRecognizer(target: self, action: Selector("handleSwipeUp"))
        swipeGesture.numberOfTouchesRequired = 2
        swipeGesture.direction = .Up
        swipeGesture.delegate = self
        self.webView.scrollView.addGestureRecognizer(swipeGesture)
        //        self.webView.scrollView.panGestureRecognizer.delegate = self
        //        self.webView.scrollView.panGestureRecognizer.requireGestureRecognizerToFail(swipeGesture)
    }

    // MARK: - Navigation
    
    func handleTitleTap() {
        self.performSegueWithIdentifier("EditWikiPage", sender: self)
    }
    
    func handleSwipeUp() {
        self.performSegueWithIdentifier("ShowAllPages", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "AddWikiPage" {
            let addPageViewController = segue.destinationViewController.topViewController as! AddPageViewController
            addPageViewController.wiki = self.wiki
            if let name = pendingPageName {
                addPageViewController.page = Page(rawContent: "", name: name, modifiedTime: NSDate(), wiki: self.wiki)
            }
        } else if segue.identifier == "EditWikiPage" {
            let addPageViewController = segue.destinationViewController.topViewController as! AddPageViewController
            addPageViewController.wiki = self.wiki
            addPageViewController.page = self.currentPage
            addPageViewController.editing = true
        } else if segue.identifier == "ShowAllPages" {
            let allPagesViewController = segue.destinationViewController.topViewController as! AllPagesViewController
            allPagesViewController.wiki = self.wiki
        }
    }
    
    func renderPage(page: Page) {
        let content = GRMustacheTemplate.renderObject([
            "title": page.name,
            "content": page.content
            ], fromResource: "layout", bundle: nil, error: nil)
        let fileName = page.permalink + ".html"
        let path = self.wiki.writeLocalFile(fileName, content: content, overwrite: true)
        self.webView.loadRequest(NSURLRequest(URL: NSURL.fileURLWithPath(path!)!))
        self.currentPage = page
        self.title = self.currentPage.name
    }
    
    func renderPermalink(permalink: String, name: String? = nil) {
        if self.wiki.isPage(permalink) {
            self.renderPage(self.wiki.page(permalink)!)
        } else {
            self.pendingPageName = name
            self.performSegueWithIdentifier("AddWikiPage", sender: self)
        }
    }
    
    func webView(
        webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: () -> Void) {
            
        var alertController = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: {
            (action) in
            completionHandler()
        }))
    
        self.presentViewController(alertController, animated: true, completion: nil);
    }
    
    
    @IBAction func cancelToWikiViewController(segue: UIStoryboardSegue) {
    }
    
    @IBAction func savePage(segue: UIStoryboardSegue) {
        let addPageViewController = segue.sourceViewController as! AddPageViewController
        if let page = addPageViewController.page {
            self.webView.reloadFromOrigin()
            self.renderPage(page)   
        }
    }
    
    @IBAction func navigateToSelectedPage(segue: UIStoryboardSegue) {
        let allPagesViewController = segue.sourceViewController as! AllPagesViewController
        self.renderPermalink(allPagesViewController.selectedPermalink)
    }
    
    @IBAction func deletePage(segue: UIStoryboardSegue) {
        self.webView.goBack()
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        if let permalink = webView.URL!.absoluteString?.lastPathComponent.stringByDeletingPathExtension {
            if permalink != self.currentPage.permalink {
                if let page = wiki.page(permalink) {
                    self.currentPage = page
                    self.title = self.currentPage.name
                }
            }
        }
    }
    
    func showImageBrowser(path: String) {
        var browser = IDMPhotoBrowser(photos: [IDMPhoto(filePath: self.wiki.localImagePath(path))])
        browser.usePopAnimation = true
        self.presentViewController(browser, animated: true, completion: nil)
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        coder.encodeObject(self.currentPage, forKey: "page")
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        self.currentPage = coder.decodeObjectForKey("page") as? Page
        self.currentPage.wiki = self.wiki
        self.currentPage.content = self.currentPage.renderHTML(self.currentPage.rawContent)
        if let page = self.currentPage {
            self.renderPage(page)
        }
    }
}

class NavigationScriptMessageHandler: NSObject, WKScriptMessageHandler {
    static var name = "navigation"
    weak var delegate: WikiViewController?
    init(delegate: WikiViewController) {
        self.delegate = delegate
    }
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if message.name == NavigationScriptMessageHandler.name {
            if let body: NSDictionary = message.body as? NSDictionary {
                let path = body.objectForKey("page") as! String
                let name = body.objectForKey("name") as! String
                let isInternal = body.objectForKey("isInternal") as! Bool
                if isInternal {
                    delegate?.renderPermalink(path.lastPathComponent, name: name)
                } else {
                    var webViewController = STKWebKitModalViewController(URL: NSURL(string: path))
                    delegate?.presentViewController(webViewController, animated: true, completion: nil)
                }
            }
        }
    }
}

class ChecklistScriptMessageHandler: NSObject, WKScriptMessageHandler {
    static var name = "updateRaw"
    weak var delegate: WikiViewController?
    init(delegate: WikiViewController) {
        self.delegate = delegate
    }
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if message.name == ChecklistScriptMessageHandler.name {
            if let body: NSDictionary = message.body as? NSDictionary {
                let rawContent = body.objectForKey("content") as! String
                delegate?.currentPage.rawContent = rawContent
                delegate?.wiki.save(delegate!.currentPage!, overwrite: true)
            }
        } else if message.name == "loaded" {
            if let string = delegate?.currentPage.rawContent {
                let js = "injectRawMarkdown(\"\(string.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)\")"
                delegate?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

}

class ImageBrowserScriptHandler: NSObject, WKScriptMessageHandler {
    static var name = "showImageBrowser"
    weak var delegate: WikiViewController?
    init(delegate: WikiViewController) {
        self.delegate = delegate
    }
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if message.name == ImageBrowserScriptHandler.name {
            if let body: NSDictionary = message.body as? NSDictionary {
                let src = (body.objectForKey("src") as! String).lastPathComponent
                delegate?.showImageBrowser(src)
            }
        }
    }
}
