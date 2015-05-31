//
//  Page.swift
//  Memex
//
//  Created by Mark Hudnall on 3/3/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import Foundation
import SwiftRegex

class Page: NSObject, NSCoding {
    var content: String?
    var permalink: String!
    var name: String!
    weak var wiki: Wiki?
    var rawContent: String!
    var modifiedTime: NSDate!
    
    init(rawContent: String, filename: String, modifiedTime: NSDate, wiki: Wiki) {
        super.init()
        
        self.rawContent = rawContent
        self.permalink = filename
        self.name = Page.permalinkToName(permalink)
        self.wiki = wiki
        self.modifiedTime = modifiedTime
        self.content = self.renderHTML(rawContent)
    }
    
    init(rawContent: String, name: String, modifiedTime: NSDate, wiki: Wiki) {
        super.init()
        
        let filename = Page.nameToPermalink(name)
        
        self.rawContent = rawContent
        self.permalink = filename
        self.name = name
        self.wiki = wiki
        self.modifiedTime = modifiedTime
        self.content = self.renderHTML(rawContent)
    }
    
    required init(coder decoder: NSCoder) {
        super.init()
        
        self.rawContent = decoder.decodeObjectForKey("rawContent") as! String
        self.permalink = decoder.decodeObjectForKey("permalink") as! String
        self.name = decoder.decodeObjectForKey("name") as! String
        self.modifiedTime = decoder.decodeObjectForKey("modifiedTime") as! NSDate
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.rawContent, forKey: "rawContent")
        coder.encodeObject(self.permalink, forKey: "permalink")
        coder.encodeObject(self.name, forKey: "name")
        coder.encodeObject(self.modifiedTime, forKey: "modifiedTime")
    }
    
    class func nameToPermalink(name: String) -> String {
        return name.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString(" ", withString: "_").lowercaseString
    }
    
    class func permalinkToName(permalink: String) -> String {
        return permalink.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
    }
    
    func renderHTML(rawContent: String) -> String {
        if let content = Hoedown.convertMarkdownString(self.parseLinks(rawContent)) {
            return content
        } else {
            return ""
        }
    }
    
    func parseLinks(rawContent: String) -> String {
//        let regex = Regex("\\[\\[(.+?)\\]\\]")
//        let parsed = regex.replace(rawContent, withBlock: { (regexMatch : RegexMatch) -> String in
//            let match = regexMatch.subgroupMatchAtIndex(0)!
//            var pageName: String!
//            var name: String!
//
//            // Handle aliases
//            let a = match.componentsSeparatedByString(":")
//            if a.count > 1 {
//                name = a[0]
//                pageName = a[1]
//            } else {
//                pageName = match
//                name = pageName
//            }
//            let permalink = pageName.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "_")
//            if self.wiki!.isPage(permalink) {
//                return "<a class=\"internal\" href=\"\(permalink)\">" + name + "</a>"
//            } else {
//                return "<a class=\"internal new\" href=\"\(permalink)\">" + name + "</a>"
//            }
//        })
//        return parsed!
        
        var mutable = RegexMutable(rawContent)
        mutable["\\[\\[(.+?)\\]\\]"] ~= {
            (groups: [String]) in
            let match = groups[1]
            
            var pageName: String!
            var name: String!
            
            // Handle aliases
            let a = match.componentsSeparatedByString(":")
            if a.count > 1 {
                name = a[0]
                pageName = a[1]
            } else {
                pageName = match
                name = pageName
            }
            let permalink = pageName.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "_")
            if self.wiki!.isPage(permalink) {
                return "<a class=\"internal\" href=\"\(permalink)\">" + name + "</a>"
            } else {
                return "<a class=\"internal new\" href=\"\(permalink)\">" + name + "</a>"
            }
        }
        return mutable as String
    }
}
