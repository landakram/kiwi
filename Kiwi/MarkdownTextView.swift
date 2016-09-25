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
    override func buttons() -> [Any]! {
        return [
            self.createButton(withTitle: "#", andEventHandler: { () -> Void in
                self.insertText("#")
            }),
            self.createButton(withTitle: "*", andEventHandler: { () -> Void in
                if (self.selectedRange.length > 0) {
                    self.wrapSelectedRange(with: "*")
                } else {
                    self.insertText("*")
                }
            }),
            self.createButton(withTitle: "Indent", andEventHandler: { () -> Void in
                self.insertText("  ")
            }),
            self.createButton(withTitle: "Wiki Link", andEventHandler: { () -> Void in
                if (self.selectedRange.length > 0) {
                    self.wrapSelectedRange(withStart: "[[", end: "]]")
                    let linkName = self.text(in: self.selectedTextRange!)
                    self.replace(self.selectedTextRange!, withText: linkName!.capitalized)
                } else {
                    var range = self.selectedRange
                    range.location += 2
                    self.insertText("[[]]")
                    self.setSelectionRange(range)
                }
            }),
            self.createButton(withTitle: "`", andEventHandler: { () -> Void in
                if (self.selectedRange.length > 0) {
                    self.wrapSelectedRange(with: "`")
                } else {
                    self.insertText("`")
                }
            }),
            self.createButton(withTitle: "Photo", andEventHandler: { () -> Void in
                let block: ImageBlock = { (filename: String?) -> Void in
                    var range = self.selectedRange
                    range.location += 2
                    self.insertText("![](img/\(filename)")
                    self.setSelectionRange(range)
                }
                self.imagePickerDelegate?.textViewWantsImage(self, completion: block)
            }),
            self.createButton(withTitle: "Link", andEventHandler: { () -> Void in
                var range = self.selectedRange
                range.location += 1
                self.insertText("[]()")
                self.setSelectionRange(range)
                
            }),
            self.createButton(withTitle: "Quote", andEventHandler: { () -> Void in
                var range = self.selectedRange
                range.location += 3
                self.insertText(self.text.characters.count == 0 ? "> " : "\n> ")
                self.setSelectionRange(range)
            })
        ]
    }
}
