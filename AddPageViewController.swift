//
//  AddPageViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/6/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import ViewUtils
import RFMarkdownTextView

class AddPageViewController: UIViewController, UITextViewDelegate, ImagePickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    var textViewHeightConstraint: NSLayoutConstraint!
    
    var textView: MarkdownTextView!
    var page: Page?
    var wiki: Wiki!
    
    var imageBlock: ImageBlock! 
    
    var bottommostVisibleText: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView = MarkdownTextView(frame: self.view.bounds)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.restorationIdentifier = "EditPageTextView"
        
        self.automaticallyAdjustsScrollViewInsets = false
        view.addSubview(textView)
        
        let dict = ["textView": textView!]
        let horizontalConstraints = NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-0-[textView]-0-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: dict)
        let verticalConstraints = NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-0-[textView]-0-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: ["textView" : textView!])
        view.addConstraints(verticalConstraints)
        view.addConstraints(horizontalConstraints)
        
        textView.isScrollEnabled = true
        textView.imagePickerDelegate = self
        textView.contentInset = UIEdgeInsets(top: self.navigationController!.navigationBar.y + self.navigationController!.navigationBar.bottom, left: 0, bottom: 0, right: 0);
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
        // 50 is estimated from the size of the left and right bar button items
        let availableWidth = self.navigationController!.navigationBar.frame.size.width - 200
        let titleField = UITextField(frame: CGRect(x: 0, y: 0, width: availableWidth, height: self.navigationController!.navigationBar.frame.size.height))
        titleField.placeholder = "Title"
        titleField.autocapitalizationType = .words
        titleField.returnKeyType = .next
        titleField.delegate = self
        titleField.textAlignment = .center
        titleField.restorationIdentifier = "EditPageTitleView"

        self.navigationItem.titleView = titleField
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "checkmark"),
            style: UIBarButtonItemStyle.plain,
            target: self,
            action: #selector(AddPageViewController.save)
        )
        
        if self.isEditing {
            if let page = self.page {
                let trashButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(AddPageViewController.deletePage))
                titleField.isUserInteractionEnabled = false
                self.navigationItem.rightBarButtonItems?.append(trashButton)
            }
        }
        
        
        if let page = self.page {
            textView.insertText(page.rawContent)
            titleField.text = page.name
        } else {
            titleField.text = ""
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AddPageViewController.textFieldDidChange),
            name: NSNotification.Name.UITextFieldTextDidChange,
            object: nil
        )
        
        if let visibleText = (self.bottommostVisibleText as NSString?) {
            var searchText: NSString = visibleText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) as NSString
            let start = min(1, searchText.length)
            let end = min(15, searchText.length)
            searchText = searchText.substring(with: NSMakeRange(start, end - start)) as NSString
            let range = (textView.text as NSString).range(of: searchText as String)
            if range.location != NSNotFound {
                textView.scrollRangeToVisible(range)
                var contentOffset = textView.contentOffset
                contentOffset.y -= textView.contentBounds.height
                textView.setContentOffset(contentOffset, animated: false)
                textView.selectedRange = NSMakeRange(range.location, 0)
            }
        }
        
        if titleField.text!.isEmpty {
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            titleField.becomeFirstResponder()
        } else {
            textView.becomeFirstResponder()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Navigation
    
    func save() {
        if shouldPerformSegue(withIdentifier: "SavePage", sender: self) {
            self.performSegue(withIdentifier: "SavePage", sender: self)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let titleField = self.navigationItem.titleView as! UITextField
        titleField.resignFirstResponder()
        textView.resignFirstResponder()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "SavePage" {
            if !self.isEditing {
                let titleField = self.navigationItem.titleView as! UITextField
                let name = titleField.text!
                self.page = Page(rawContent: textView.text, permalink: Page.nameToPermalink(name: name), name: name, modifiedTime: Date(), createdTime: Date(), isDirty: true)
            } else {
                self.page?.rawContent = textView.text
            }
            
            switch self.wiki.save(page!, overwrite: isEditing) {
                case SaveResult.success:
                    break
                case SaveResult.fileExists:
                    let alertController = UIAlertController(
                        title: "That page already exists",
                        message: nil,
                        preferredStyle: .actionSheet)
                    
                    let overwriteAction = UIAlertAction(title: "Overwrite it", style: .destructive, handler: { (action) in
                        self.wiki.save(self.page!, overwrite: true)
                        self.performSegue(withIdentifier: identifier, sender: sender)
                    })
                    
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    
                    alertController.addAction(overwriteAction)
                    alertController.addAction(cancelAction)
                    
                    alertController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
                    
                    present(alertController, animated: true, completion: nil)
                    return false
            }
        }
        return true
    }
    
    func deletePage() {
        if var actualPage = self.page {
            var titleText = "Are you sure you want to delete this page?"
            if actualPage.permalink == "home" {
                titleText = "Are you sure you want to clear this page?"
            }
            
            let overwriteActionTitle = actualPage.permalink == "home" ? "Clear it" : "Delete it"
            
            let alertController = UIAlertController(
                title: titleText,
                message: nil,
                preferredStyle: .actionSheet)
            
            let overwriteAction = UIAlertAction(title: overwriteActionTitle, style: .destructive, handler: { (action) in
                if actualPage.permalink == "home" {
                    actualPage.rawContent = ""
                    self.wiki.save(actualPage, overwrite: true)
                    self.performSegue(withIdentifier: "SavePage", sender: self)
                } else {
                    self.wiki.delete(actualPage)
                    self.performSegue(withIdentifier: "DeletePage", sender: self)
                }
            })
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alertController.addAction(overwriteAction)
            alertController.addAction(cancelAction)
            
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func textViewWantsImage(_ textView: RFMarkdownTextView!, completion imageBlock: ImageBlock!) {
        let picker: UIImagePickerController = UIImagePickerController()
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .popover
        picker.delegate = self
        
        self.imageBlock = imageBlock
        picker.popoverPresentationController?.sourceView = textView
        picker.popoverPresentationController?.sourceRect = textView.caretRect(for: (textView.selectedTextRange?.start)!)
        self.present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        
        let chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        let imageFileName = self.wiki.saveImage(chosenImage)
        
        imageBlock(imageFileName)
    }
    
    func textFieldDidChange() {
        let textField = self.navigationItem.titleView as! UITextField
        self.navigationItem.rightBarButtonItem?.isEnabled = !textField.text!.isEmpty
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textView.becomeFirstResponder()
        return true
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(self.textView.text, forKey: "editedText")
        if let page = self.page {
            coder.encode(EncodablePage(page: page), forKey: "page")
        }
        
        let titleField = self.navigationItem.titleView as! UITextField
        coder.encode(titleField.text, forKey: "titleText")
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        let encodablePage = coder.decodeObject(forKey: "page") as? EncodablePage
        self.page = encodablePage?.page
        self.wiki = Wiki()
        self.textView.insertText(coder.decodeObject(forKey: "editedText") as! String)
        
        let titleField = self.navigationItem.titleView as! UITextField
        titleField.text = coder.decodeObject(forKey: "titleText") as! String
        textFieldDidChange()
    }
}
