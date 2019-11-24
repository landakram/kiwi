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
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            _sharedInstance = YapDatabase(path: documentsURL.appendingPathComponent("wiki.sqlite").absoluteString)
            
            let block: YapDatabaseFullTextSearchWithObjectBlock = {
                (transaction: YapDatabaseReadTransaction, dict: NSMutableDictionary, collection: String, key: String, object: Any) in
                
                if let encodablePage = object as? EncodablePage {
                    let page = encodablePage.page
                    dict.setObject(page.rawContent, forKey: "rawContent" as NSCopying)
                    dict.setObject(page.permalink, forKey: "permalink" as NSCopying)
                    dict.setObject(page.name, forKey: "name" as NSCopying)
                }
            }
            
            let propertiesToIndexForSearch = ["rawContent", "permalink", "name"]
            
            let fullTextSearch = YapDatabaseFullTextSearch(
                columnNames: propertiesToIndexForSearch,
                handler: YapDatabaseFullTextSearchHandler.withObjectBlock(block)
            )
            
            _sharedInstance?.register(fullTextSearch, withName: "fts")
        }
        
        return _sharedInstance!
    }
}
