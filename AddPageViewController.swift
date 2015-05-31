//
//  AddPageViewController.swift
//  Memex
//
//  Created by Mark Hudnall on 3/6/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import RFMarkdownTextView

class AddPageViewController: UIViewController, UITextViewDelegate, ImagePickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    var textViewHeightConstraint: NSLayoutConstraint!
    
    var textView: RFMarkdownTextView!
    var page: Page?
    var wiki: Wiki!
    
    var imageBlock: ImageBlock!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView = RFMarkdownTextView(frame: self.view.frame)
        textView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.automaticallyAdjustsScrollViewInsets = true
        view.addSubview(textView)
        
        var dict = ["textView": textView]
        var horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
            "H:|-0-[textView]-0-|",
            options: NSLayoutFormatOptions(0),
            metrics: nil,
            views: dict)
        var verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
            "V:|-0-[textView]-0-|",
            options: NSLayoutFormatOptions(0),
            metrics: nil,
            views: ["textView" : textView])
        view.addConstraints(verticalConstraints)
        view.addConstraints(horizontalConstraints)
        
        textView.scrollEnabled = true
        textView.imagePickerDelegate = self
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
        // 50 is estimated from the size of the left and right bar button items
        let availableWidth = self.navigationController!.navigationBar.frame.size.width - 200
        let titleField = UITextField(frame: CGRect(x: 0, y: 0, width: availableWidth, height: self.navigationController!.navigationBar.frame.size.height))
//        let titleField = UITextField(frame: self.navigationController!.navigationBar.frame)
        titleField.placeholder = "Title"
        titleField.autocapitalizationType = .Words
        titleField.returnKeyType = .Next
        titleField.delegate = self
        titleField.textAlignment = .Center
        self.navigationItem.titleView = titleField
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "checkmark"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: Selector("save")
        )
        
        if self.editing {
            let trashButton = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: Selector("deletePage"))
            self.navigationItem.rightBarButtonItems?.append(trashButton)
        }
        
        
        if let page = self.page {
            textView.insertText(page.rawContent)
            titleField.text = page.name
        }
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("textFieldDidChange"),
            name: UITextFieldTextDidChangeNotification,
            object: nil
        )
        
        if titleField.text.isEmpty {
            self.navigationItem.rightBarButtonItem?.enabled = false
            titleField.becomeFirstResponder()
        } else {
            textView.becomeFirstResponder()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Navigation
    
    func save() {
        if shouldPerformSegueWithIdentifier("SavePage", sender: self) {
            self.performSegueWithIdentifier("SavePage", sender: self)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let titleField = self.navigationItem.titleView as! UITextField
        titleField.resignFirstResponder()
        textView.resignFirstResponder()
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if identifier == "SavePage" {
            if !self.editing {
                let titleField = self.navigationItem.titleView as! UITextField
                self.page = Page(rawContent: textView.text, name: titleField.text, modifiedTime: NSDate(), wiki: self.wiki)
            } else {
                self.page?.rawContent = textView.text
            }
            
            switch self.wiki.save(page!, overwrite: editing) {
            case SaveResult.Success:
                break
            case SaveResult.FileExists:
                let alertController = UIAlertController(
                    title: "That page already exists",
                    message: nil,
                    preferredStyle: .ActionSheet)
                
                let overwriteAction = UIAlertAction(title: "Overwrite it", style: .Destructive, handler: { (action) in
                    self.wiki.save(self.page!, overwrite: true)
                    self.performSegueWithIdentifier(identifier, sender: sender)
                })
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
                
                alertController.addAction(overwriteAction)
                alertController.addAction(cancelAction)
                
                presentViewController(alertController, animated: true, completion: nil)
                return false
            }
        }
        return true
    }
    
    func deletePage() {
        if let actualPage = self.page {
            let alertController = UIAlertController(
                title: "Are you sure you want to delete this page?",
                message: nil,
                preferredStyle: .ActionSheet)
            
            let overwriteAction = UIAlertAction(title: "Delete it", style: .Destructive, handler: { (action) in
                self.wiki.delete(actualPage)
                self.performSegueWithIdentifier("DeletePage", sender: self)
            })
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            
            alertController.addAction(overwriteAction)
            alertController.addAction(cancelAction)
            
            presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    func textViewWantsImage(textView: RFMarkdownTextView!, completion imageBlock: ImageBlock!) {
        var picker: UIImagePickerController = UIImagePickerController()
        picker.allowsEditing = false
        picker.sourceType = .PhotoLibrary
        picker.modalPresentationStyle = .Popover
        picker.delegate = self
        
        self.imageBlock = imageBlock
        self.presentViewController(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        dismissViewControllerAnimated(true, completion: nil)
        
        var chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        var imageFileName = self.wiki.saveImage(chosenImage)
        
        imageBlock(imageFileName)
        
    }
    
    func textFieldDidChange() {
        let textField = self.navigationItem.titleView as! UITextField
        self.navigationItem.rightBarButtonItem?.enabled = !textField.text.isEmpty
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.textView.becomeFirstResponder()
        return true
    }
}
