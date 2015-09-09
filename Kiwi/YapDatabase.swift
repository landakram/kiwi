//
//  YapDatabase.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/15/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import Foundation
import YapDatabase

private var _sharedInstance: YapDatabase?

class Yap {
    class var sharedInstance: YapDatabase {
        if _sharedInstance == nil {
            _sharedInstance = YapDatabase(path: NSTemporaryDirectory().stringByAppendingPathComponent("wiki.sqlite"))
            
            var block: YapDatabaseFullTextSearchWithObjectBlock = {
                (dict: NSMutableDictionary!, collection: String!, key: String!, object: AnyObject!) in
                
                if let page = object as? Page {
                    dict.setObject(page.rawContent, forKey: "rawContent")
                    dict.setObject(page.permalink, forKey: "permalink")
                    dict.setObject(page.name, forKey: "name")
                }
            }
            
            var propertiesToIndexForSearch = ["rawContent", "permalink", "name"]
            
            var fullTextSearch = YapDatabaseFullTextSearch(
                columnNames: propertiesToIndexForSearch,
                handler: YapDatabaseFullTextSearchHandler.withObjectBlock(block)
            )
            
            _sharedInstance?.registerExtension(fullTextSearch, withName: "fts")
        }
        
        return _sharedInstance!
    }
}