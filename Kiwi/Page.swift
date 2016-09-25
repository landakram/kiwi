//
//  Page.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/3/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import Foundation

protocol HTMLable {
    func toHTML() -> String
}

protocol TransformsMarkdownToHTML {
    func markdownToHTML(_ markdown: String) -> String
}

extension TransformsMarkdownToHTML {
    func markdownToHTML(_ markdown: String) -> String {
        guard let content = Hoedown.convertMarkdownString(markdown) else {
            return ""
        }
        return content
    }
}

protocol TransformsLinksToAnchors {
    func linksToAnchors(_ markdown: String) -> String
    func linkToAnchor(_ link: String) -> String
    static func permalinkToClassNames(_ permalink: String) -> [String]
}

extension String {
    func nsRange(from range: Range<String.Index>) -> NSRange {
        let utf16view = self.utf16
        let from = range.lowerBound.samePosition(in: utf16view)
        let to = range.upperBound.samePosition(in: utf16view)
        return NSMakeRange(utf16view.distance(from: utf16view.startIndex, to: from),
                           utf16view.distance(from: from, to: to))
    }
}

extension String {
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self)
            else { return nil }
        return from ..< to
    }
}

extension TransformsLinksToAnchors {
    func linksToAnchors(_ markdown: String) -> String {
        let regex = try! NSRegularExpression(pattern: "\\[\\[(.+?)\\]\\]", options: .caseInsensitive)
        
        let out = NSMutableString()
        var pos = markdown.startIndex
        
        // This logic was extracted / modified from SwiftRegex.swift.
        // It's naive -- in the ideal world, I would refactor to a 
        // function: `replaceMatches(in: ..., options: ..., matchFunction: ...)`
        regex.enumerateMatches(in: markdown,
                               options: NSRegularExpression.MatchingOptions(rawValue: 0),
                               range: NSRange(location:0, length:markdown.characters.count))
        { (match: NSTextCheckingResult?, flags: NSRegularExpression.MatchingFlags, stop: UnsafeMutablePointer<ObjCBool>) in
            guard let match = match else { return }
            
            let matchRange = markdown.range(from: match.range)
            
            // Append everything before the match
            let posToMatchSnippet = markdown.substring(with: Range<String.Index>(uncheckedBounds: (lower: pos, upper: matchRange!.lowerBound)))
            out.append( posToMatchSnippet )
            
            // Find the groups in the match
            var groups = [String]()
            for groupno in 0...regex.numberOfCaptureGroups {
                let groupRange = markdown.range(from: match.rangeAt(groupno))
                if let group = markdown.substring( with: groupRange! ) as String! {
                    groups.append( group )
                }
            }
            
            // Replace the group we care about with a replacement string
            let capturedMatch = groups[1]
            let replacement = self.linkToAnchor(capturedMatch)
            
            // Append the replacement instead of the match
            out.append(replacement)
            pos = matchRange!.upperBound
        }
        
        // Finally, replace everything from the end of the last match to 
        // the end of the string
        let rest = markdown.substring(from: pos)
        out.append(rest)
        return out as String
    }
    
    func linkToAnchor(_ link: String) -> String {
        var pageName: String!
        var name: String!
        
        // Handle aliases
        let a = link.components(separatedBy: ":")
        if a.count > 1 {
            name = a[0]
            pageName = a[1]
        } else {
            pageName = link
            name = pageName
        }
        let permalink = pageName.lowercased().replacingOccurrences(of: " ", with: "_")
        let classNames = type(of: self).permalinkToClassNames(permalink)
        let classNamesString = classNames.joined(separator: " ")
        return "<a class=\"\(classNamesString)\" href=\"\(permalink)\">\(name!)</a>"
    }
}

class PageCoder: NSObject, NSCoding {
    let page: Page
    
    init(page: Page) {
        self.page = page
    }
    
    required init?(coder decoder: NSCoder) {
        let rawContent = decoder.decodeObject(forKey: "rawContent") as! String
        let permalink = decoder.decodeObject(forKey: "permalink") as! String
        let name = decoder.decodeObject(forKey: "name") as! String
        let modifiedTime = (decoder.decodeObject(forKey: "modifiedTime") as! NSDate) as Date
        let createdTime = (decoder.decodeObject(forKey: "createdTime") as! NSDate) as Date
        
        self.page = Page(rawContent: rawContent, permalink: permalink, name: name, modifiedTime: modifiedTime, createdTime: createdTime, isDirty: false)
    }
    func encode(with coder: NSCoder) {
        coder.encode(self.page.rawContent, forKey: "rawContent")
        coder.encode(self.page.permalink, forKey: "permalink")
        coder.encode(self.page.name, forKey: "name")
        coder.encode(self.page.modifiedTime, forKey: "modifiedTime")
        coder.encode(self.page.createdTime, forKey: "createdTime")
    }
}

struct Page: HTMLable, TransformsMarkdownToHTML, TransformsLinksToAnchors {
    var rawContent: String
    var permalink: String
    var name: String
    var modifiedTime: Date
    var createdTime: Date
    var isDirty: Bool
    
    func toHTML() -> String {
        return markdownToHTML(linksToAnchors(self.rawContent))
    }
    
    static func permalinkToClassNames(_ permalink: String) -> [String] {
        if Wiki.isPage(permalink) {
            return ["internal"]
        } else {
            return ["internal", "new"]
        }
    }
    
    static func nameToPermalink(name: String) -> String {
        return name.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_").lowercased()
    }

    static func permalinkToName(permalink: String) -> String {
        return permalink.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
