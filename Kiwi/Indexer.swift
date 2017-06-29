//
//  Indexer.swift
//  Kiwi
//
//  Created by Mark Hudnall on 11/12/16.
//  Copyright © 2016 Mark Hudnall. All rights reserved.
//

import Foundation
import YapDatabase
import YapDatabase.YapDatabaseFullTextSearch
import RxSwift

class Indexer {
    static let sharedInstance = Indexer()
    
    let backingStore: YapDatabase
    let filesystem: Filesystem
    let indexingRoot: Path
    
    var disposeBag = DisposeBag()
    
    init(backingStore: YapDatabase = Yap.sharedInstance, filesystem: Filesystem = Filesystem.sharedInstance, root: Path = Wiki.WIKI_PATH) {
        self.backingStore = backingStore
        self.filesystem = filesystem
        self.indexingRoot = root
        self.start()
    }
    
    func start() {
        self.filesystem.events.subscribe(onNext: { (event: FilesystemEvent) in
            switch event {
            case .delete(let path):
                let relativePath = path.relativeTo(self.filesystem.root)
                if self.pathIsIndexed(path: relativePath) {
                    let permalink = pathToPermalink(path: path)
                    self.remove(permalink: permalink)
                }
            case .write(let path):
                let relativePath = path.relativeTo(self.filesystem.root)
                if self.pathIsIndexed(path: relativePath) {
                    do {
                        let file: File<String> = try self.filesystem.read(path: relativePath)
                        if let page = toPage(file) {
                            self.index(page: page)
                        }
                    } catch {
                        
                    }
                }
            }
        }).disposed(by: self.disposeBag)
    }
    
    private func pathIsIndexed(path: Path) -> Bool {
        return path.commonAncestor(self.indexingRoot) == self.indexingRoot
    }
    
    func remove(permalink: String) {
        let connection = self.backingStore.newConnection()
        connection.readWrite { (transaction: YapDatabaseReadWriteTransaction) in
            transaction.removeObject(forKey: permalink, inCollection: "pages")
        }
    }
    
    func index(page: Page) {
        let connection = self.backingStore.newConnection()
        connection.readWrite({ (transaction: YapDatabaseReadWriteTransaction!) in
            let encodablePage = transaction.object(forKey: page.permalink, inCollection: "pages") as? EncodablePage
            if encodablePage == nil || encodablePage!.page.modifiedTime.compare(page.modifiedTime as Date) == .orderedAscending {
                transaction.setObject(EncodablePage(page: page), forKey: page.permalink, inCollection: "pages")
            }
        })
    }
    
    func get(permalink: String) -> Page? {
        var page: Page?
        
        // TODO: previously, this used `beginLongLivedReadTransaction` but I removed it here.
        // Does that matter?
        self.backingStore.newConnection().read({ (transaction) in
            if let encodablePage = transaction.object(forKey: permalink, inCollection: "pages") as? EncodablePage {
                page = encodablePage.page
            }
        })
        
        return page
    }
    
    func find(snippet: String) -> [String] {
        var results: [String] = []

        self.backingStore.newConnection().read({ (transaction: YapDatabaseReadTransaction) in
            let t = transaction.ext("fts") as! YapDatabaseFullTextSearchTransaction
            t.enumerateKeys(matching: snippet, using: { (collection, key, stop) in
                results.append(key)
            })
        })
        
        return results
    }
}

class EncodablePage: NSObject, NSCoding {
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
