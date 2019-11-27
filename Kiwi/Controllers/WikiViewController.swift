//
//  WikiViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/5/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import WebKit
import GRMustache
import IDMPhotoBrowser
import STKWebKitViewController
import TUSafariActivity
import RxSwift
import AMScrollingNavbar

class WikiViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, UIGestureRecognizerDelegate, ScrollingNavigationControllerDelegate {
    
    var titleView : UIButton!
    
    var webView: WKWebView!
    var wiki: Wiki!
    var currentPage: Page!
    
    var pendingPageName: String?
    
    var bottommostVisibleText: String?
    
    var disposeBag: DisposeBag = DisposeBag()
    
    override var title: String? {
        set {
            super.title = newValue
            UIView.performWithoutAnimation { () -> Void in
                self.titleView.setTitle(newValue, for: UIControlState())
                self.titleView.sizeToFit()
                self.titleView.layoutIfNeeded()
            }
        }
        get {
            return super.title
        }
    }
    
    func reload() {
        if let page: Page = self.wiki.page(self.currentPage.permalink) {
            self.renderPage(page)   
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = false;
        
        self.setupWebView()
        self.setUpWiki()
    }
    
    func setUpWiki() {
        self.wiki = Wiki()
        
        if (self.isLoadingForFirstTime()) {
            self.wiki.writeDefaultFiles()
            self.setLoadedFirstTime()
        }
        
        // TODO: these are related to actually rendering the wiki as HTML and should not be in the Wiki class
        self.wiki.writeResouceFiles()
        self.wiki.copyImagesToLocalCache()
        
        self.renderPermalink("home")
        
        self.wiki.stream.subscribe(onNext: { (event: WikiEvent) in
            switch event {
            case .writeImage(let path):
                self.wiki.copyImageToLocalCache(path: path)
                if self.currentPage.rawContent.contains(path.fileName) {
                    self.reload()
                }
            case .writePage(let page):
                if page.permalink == self.currentPage.permalink {
                    self.reload()
                }
            }
        }).disposed(by: disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let navigationController = navigationController as? ScrollingNavigationController {
            navigationController.followScrollView(self.webView, delay: 50.0, scrollSpeedFactor: 1.0, followers: [NavigationBarFollower(view: self.webView)])
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let navigationController = navigationController as? ScrollingNavigationController {
            navigationController.stopFollowingScrollView()
        }
    }

    func isLoadingForFirstTime() -> Bool {
        return !UserDefaults.standard.bool(forKey: "didLoadFirstTime")
    }
    
    func setLoadedFirstTime() {
        UserDefaults.standard.set(true, forKey: "didLoadFirstTime")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Mark: - Setup
    
    override func viewDidLayoutSubviews() {
        // This stupid hack is the only way I've figured out how to get the page to stop
        // jumping upon swipe.
        // I *should* be able to do:
        //     self.webView.scrollView.contentInset = UIEdgeInsetsMake(self.navigationController?.navigationBar.bottom ?? 0, 0, 0, 0)
        // But this simply does not work. 
        // Strangely, this does not jump:
        //     self.webView.scrollView.contentInset = .zero
        // But then content is hidden behind the navigation bar.
        // Combined with setting self.webView as a "follower" of the navbar, this 
        // produces the desired behavior
        self.webView.frame.origin.y = navigationController?.navigationBar.bottom ?? 0
    }
    
    func setupWebView() {
        let userContentController = WKUserContentController()
        let handler = NavigationScriptMessageHandler(delegate: self)
        userContentController.add(handler, name: NavigationScriptMessageHandler.name)
        let imageHandler = ImageBrowserScriptHandler(delegate: self)
        userContentController.add(imageHandler, name: ImageBrowserScriptHandler.name)
        let checklistHandler = ChecklistScriptMessageHandler(delegate: self)
        userContentController.add(checklistHandler, name: ChecklistScriptMessageHandler.name)
        userContentController.add(checklistHandler, name: "loaded")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        self.webView.restorationIdentifier = "WikiWebView"
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.uiDelegate = self
        self.webView.navigationDelegate = self
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.view.addSubview(self.webView)
        
        let horizontalConstraints = NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-0-[webView(view)]-0-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: ["webView": webView, "view": view])
        let verticalConstraints = NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-0-[webView(view)]-0-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: ["webView": webView, "view": view])
        
        view.addConstraints(horizontalConstraints)
        view.addConstraints(verticalConstraints)

        titleView = UIButton(type: .system)
        titleView.sizeToFit()
        titleView.titleLabel!.font = UIFont.systemFont(ofSize: 18)
        titleView.isUserInteractionEnabled = true
        titleView.addTarget(self, action: #selector(WikiViewController.handleTitleTap), for: UIControlEvents.touchUpInside)
        titleView.setTitleColor(Constants.KiwiColor, for: UIControlState())
        self.navigationController?.navigationItem.titleView = titleView
        self.navigationItem.titleView = titleView
    }

    // MARK: - Navigation
    
    @objc func handleTitleTap() {
        self.performSegue(withIdentifier: "ShowAllPages", sender: self)
    }
    
    func handleSwipeUp() {
        self.performSegue(withIdentifier: "ShowAllPages", sender: self)
    }

    @IBAction func editPage(_ sender: UIBarButtonItem) {
        self.webView!.evaluateJavaScript("getBottommostVisibleText()", completionHandler: { (text: Any?, error: Error?) -> Void in
            if let text = text as? String {
                self.bottommostVisibleText = text
                self.performSegue(withIdentifier: "EditWikiPage", sender: sender)
            }
        });
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AddWikiPage" {
            let addPageViewController = (segue.destination as! UINavigationController).topViewController as! AddPageViewController
            addPageViewController.wiki = self.wiki
            if let name = pendingPageName {
                addPageViewController.page = Page(rawContent: "", permalink: Page.nameToPermalink(name: name), name: name, modifiedTime: Date(), createdTime: Date(), isDirty: true)
            }
            self.pendingPageName = nil
        } else if segue.identifier == "EditWikiPage" {
            let addPageViewController = (segue.destination as! UINavigationController).topViewController as! AddPageViewController
            addPageViewController.wiki = self.wiki
            addPageViewController.page = self.currentPage
            addPageViewController.bottommostVisibleText = self.bottommostVisibleText
            addPageViewController.isEditing = true
        } else if segue.identifier == "ShowAllPages" {
            let allPagesViewController = (segue.destination as! UINavigationController).topViewController as! AllPagesViewController
            allPagesViewController.files = self.wiki.files()
            allPagesViewController.indexer = self.wiki.indexer
        }
    }
    
    func renderPage(_ page: Page) {
        do {
            let variables: [String: String] = [
                "title": page.name,
                "content": page.toHTML()
            ]
            let content = try GRMustacheTemplate.renderObject(variables, fromResource: "layout", bundle: nil)
            let fileName = page.permalink + ".html"
            let path = self.wiki.writeLocalFile(fileName, content: content, overwrite: true)
            self.webView.load(URLRequest(url: URL(fileURLWithPath: path!)))
            self.currentPage = page
            self.title = self.currentPage.name

        } catch {
            return
        }
    }
    
    func renderPermalink(_ permalink: String, name: String? = nil) {
        if self.wiki.isPage(permalink) {
            self.renderPage(self.wiki.page(permalink)!)
        } else {
            self.pendingPageName = name
            self.performSegue(withIdentifier: "AddWikiPage", sender: self)
        }
    }
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void) {
            
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: {
            (action) in
            completionHandler()
        }))
    
        self.present(alertController, animated: true, completion: nil);
    }
    
    
    @IBAction func cancelToWikiViewController(_ segue: UIStoryboardSegue) {
    }
    
    @IBAction func savePage(_ segue: UIStoryboardSegue) {
        let addPageViewController = segue.source as! AddPageViewController
        if let page = addPageViewController.page {
            self.webView.reloadFromOrigin()
            self.renderPage(page)   
        }
    }
    
    @IBAction func navigateToSelectedPage(_ segue: UIStoryboardSegue) {
        let allPagesViewController = segue.source as! AllPagesViewController
        self.renderPermalink(allPagesViewController.selectedPermalink)
    }
    
    @IBAction func deletePage(_ segue: UIStoryboardSegue) {
        self.webView.goBack()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let permalink : String = webView.url?.absoluteString.lastPathComponent.stringByDeletingPathExtension {
            if permalink != self.currentPage.permalink {
                if let page = self.wiki.page(permalink) {
                    self.currentPage = page
                    self.title = self.currentPage.name
                }
            }
        }
    }
    
    func showImageBrowser(_ path: String, sources: [String], index: UInt) {
        let photos = sources.map({ (src: String) -> IDMPhoto in
            if src.range(of: "file://") != nil {
                return IDMPhoto(filePath: self.wiki.localImagePath(src.lastPathComponent))
            } else {
                return IDMPhoto(url: URL(string: src))
            }
        })
        let browser = IDMPhotoBrowser(photos: photos)
        browser?.usePopAnimation = false
        browser?.displayActionButton = false
        browser?.setInitialPageIndex(index)
        self.present(browser!, animated: true, completion: nil)
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(EncodablePage(page: self.currentPage), forKey: "page")
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        let encodablePage = coder.decodeObject(forKey: "page") as? EncodablePage
        self.currentPage = encodablePage?.page
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
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == NavigationScriptMessageHandler.name {
            if let body: NSDictionary = message.body as? NSDictionary {
                let path = body.object(forKey: "page") as! String
                let name = body.object(forKey: "name") as! String
                let isInternal = body.object(forKey: "isInternal") as! Bool
                if isInternal {
                    delegate?.renderPermalink(path.lastPathComponent.removingPercentEncoding!, name: name)
                } else {
                    let webViewController = STKWebKitModalViewController(address: path)
                    webViewController?.webKitViewController.applicationActivities = [TUSafariActivity()]
                    delegate?.present(webViewController!, animated: true, completion: nil)
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
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == ChecklistScriptMessageHandler.name {
            if let body: NSDictionary = message.body as? NSDictionary {
                let rawContent = body.object(forKey: "content") as! String
                delegate?.currentPage.rawContent = rawContent
                delegate?.wiki.save(delegate!.currentPage!, overwrite: true)
            }
        } else if message.name == "loaded" {
            if let string = delegate?.currentPage.rawContent {
                let escapedMarkdown = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                let js = "injectRawMarkdown(\"\(escapedMarkdown!)\")"
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
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == ImageBrowserScriptHandler.name {
            if let body: NSDictionary = message.body as? NSDictionary {
                let src = (body.object(forKey: "src") as! String)
                let index = (body.object(forKey: "index") as! UInt)
                let sources: [String] = (body.object(forKey: "images") as! [String])
                delegate?.showImageBrowser(src, sources: sources, index: index)
            }
        }
    }
}
