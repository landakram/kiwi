//
//  Page.swift
//  Memex
//
//  Created by Mark Hudnall on 3/3/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import Foundation

class Page {
    var content: String!
    var permalink: String
    var name: String
    var wiki: Wiki
    var rawContent: String
    
    init(rawContent: String, filename: String, wiki: Wiki) {
        self.rawContent = rawContent
        self.permalink = filename
        self.name = Page.permalinkToName(permalink)
        self.wiki = wiki
        self.content = self.renderHTML(rawContent)
    }
    
    init(rawContent: String, name: String, wiki: Wiki) {
        let filename = Page.nameToPermalink(name)
        
        self.rawContent = rawContent
        self.permalink = filename
        self.name = name
        self.wiki = wiki
        self.content = self.renderHTML(rawContent)
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
            if self.wiki.isPage(permalink) {
                return "<a class=\"internal\" href=\"\(permalink)\">" + name + "</a>"
            } else {
                return "<a class=\"internal new\" href=\"\(permalink)\">" + name + "</a>"
            }
        }
        return mutable
    }
}
