//
//  MarkdownTextView.swift
//  Kiwi
//
//  Created by Mark Hudnall on 1/26/16.
//  Copyright © 2016 Mark Hudnall. All rights reserved.
//

import Foundation
import RFMarkdownTextView

class MarkdownTextView: RFMarkdownTextView {
    override func buttons() -> [AnyObject]! {
        return [
            self.createButtonWithTitle("#", andEventHandler: { () -> Void in
                self.insertText("#")
            }),
            self.createButtonWithTitle("*", andEventHandler: { () -> Void in
                if (self.selectedRange.length > 0) {
                    self.wrapSelectedRangeWithString("*")
                } else {
                    self.insertText("*")
                }
            }),
            self.createButtonWithTitle("Indent", andEventHandler: { () -> Void in
                self.insertText("  ")
            }),
            self.createButtonWithTitle("Wiki Link", andEventHandler: { () -> Void in
                if (self.selectedRange.length > 0) {
                    self.wrapSelectedRangeWithStartString("[[", endString: "]]")
                    let linkName = self.textInRange(self.selectedTextRange!)
                    self.replaceRange(self.selectedTextRange!, withText: linkName!.capitalizedString)
                } else {
                    var range = self.selectedRange
                    range.location += 2
                    self.insertText("[[]]")
                    self.setSelectionRange(range)
                }
            }),
            self.createButtonWithTitle("`", andEventHandler: { () -> Void in
                if (self.selectedRange.length > 0) {
                    self.wrapSelectedRangeWithString("`")
                } else {
                    self.insertText("`")
                }
            }),
            self.createButtonWithTitle("Photo", andEventHandler: { () -> Void in
                let block: ImageBlock = { (filename: String!) -> Void in
                    var range = self.selectedRange
                    range.location += 2
                    self.insertText("![](img/\(filename)")
                    self.setSelectionRange(range)
                }
                
                self.imagePickerDelegate?.textViewWantsImage(self, completion: block)
            }),
            self.createButtonWithTitle("Link", andEventHandler: { () -> Void in
                var range = self.selectedRange
                range.location += 1
                self.insertText("[]()")
                self.setSelectionRange(range)
                
            }),
            self.createButtonWithTitle("Quote", andEventHandler: { () -> Void in
                var range = self.selectedRange
                range.location += 3
                self.insertText(self.text.characters.count == 0 ? "> " : "\n> ")
                self.setSelectionRange(range)
            })
        ]
    }
}