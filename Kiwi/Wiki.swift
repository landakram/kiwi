//
//  Wiki.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/3/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import Foundation
import YapDatabase
import Async

enum SaveResult {
    case Success
    case FileExists
}

class Wiki {
    static let WIKI_PATH: DBPath! = DBPath.root().childPath("wiki")
    static let STATIC_PATH: DBPath! = DBPath.root().childPath("public")
    
    static let IMG_PATH = Wiki.STATIC_PATH.childPath("img")
    static let STYLES_PATH = Wiki.STATIC_PATH.childPath("css")
    
    init() {
        let defaultFolderPaths = [
            Wiki.WIKI_PATH,
            Wiki.STATIC_PATH,
            Wiki.IMG_PATH,
            Wiki.STYLES_PATH
        ]
        for folderPath in defaultFolderPaths {
            Wiki.createFolder(folderPath)
        }
        
        // Write default files if they don't already exist
        if (self.isLoadingForFirstTime()) {
            let defaultPermalinks = [
                "home",
                "working_with_pages",
                "writing_with_kiwi",
                "acknowledgements",
                "available_in_dropbox"
            ]
            for permalink in defaultPermalinks {
                let wikiPath = Wiki.WIKI_PATH.childPath("\(permalink).md")
                writeDefaultFile(permalink, ofType: "md", toPath: wikiPath)
            }
            
            self.setLoadedFirstTime()
        }
        
        self.writeResouceFiles()
        // Copy images to local cache if they aren't already copied
        if let imgFiles = DBFilesystem.sharedFilesystem().listFolder(Wiki.IMG_PATH, error: nil) {
            for fileInfo in imgFiles {
                if let info = fileInfo as? DBFileInfo {
                    let filename = info.path.stringValue()
                    if !self.localImageExists(filename) {
                        if let file = DBFilesystem.sharedFilesystem().openFile(info.path, error: nil) {
                            if !file.status.cached {
                                // Weeee
                                file.addObserver(self, block: { () -> Void in
                                    if file.status.cached {
                                        file.removeObserver(self)
                                        self.writeLocalImage(info.path.stringValue().lastPathComponent, data: file.readData(nil))
                                    }
                                })
                            } else {
                                self.writeLocalImage(info.path.stringValue().lastPathComponent, data: file.readData(nil))
                            }
                        }
                    }
                }
            }
        }
        
        // Persist files to YapDatabase for search
        Async.main(after: 0.5) { () -> Void in
            DBFilesystem.sharedFilesystem().addObserver(self, forPathAndDescendants: Wiki.WIKI_PATH) {
                if !DBFilesystem.sharedFilesystem().status.download.inProgress {
                    Async.background {
                        self.syncUpdatedPagesToYapDatabase()
                    }
                }
            }
        }
    }
    
    deinit {
        DBFilesystem.sharedFilesystem().removeObserver(self)
    }
    
    func isLoadingForFirstTime() -> Bool {
        return !NSUserDefaults.standardUserDefaults().boolForKey("didLoadFirstTime")
    }
    
    func setLoadedFirstTime() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "didLoadFirstTime")
    }
    
    func writeResouceFiles() {
        let defaultJsFiles = [
            "links",
            "auto-render-latex.min",
            "prism",
            "jquery.min"
        ]
        for filename in defaultJsFiles {
            copyFileToLocal(NSBundle.mainBundle().pathForResource(filename, ofType: "js")!)
        }
        
        let defaultCSSFiles = [
            "screen",
            "prism"
        ]
        for filename in defaultCSSFiles {
            copyFileToLocal(NSBundle.mainBundle().pathForResource(filename, ofType: "css")!)
        }
    }
    
    func getAllFileInfos() -> [DBFileInfo]? {
        return DBFilesystem.sharedFilesystem().listFolder(Wiki.WIKI_PATH, error: nil) as? [DBFileInfo]
    }
    
    func syncUpdatedPagesToYapDatabase() {
        if let wikiFiles = getAllFileInfos() {
            for info in wikiFiles {
                if let file = DBFilesystem.sharedFilesystem().openFile(info.path, error: nil) {
                    let permalink = info.path.stringValue().lastPathComponent.stringByDeletingPathExtension
                    if !file.status.cached {
                        file.addObserver(self, block: {
                            if file.status.cached {
                                file.removeObserver(self)
                                self.persistToYapDatabase(file)
                            }
                        })
                    } else {
                        self.persistToYapDatabase(file)
                    }
                }
            }
        }
    }
    
    func persistToYapDatabase(file: DBFile) {
        if let page = self.page(file) {
            var connection = Yap.sharedInstance.newConnection()
            connection.readWriteWithBlock({ (transaction: YapDatabaseReadWriteTransaction!) in
                let persistedPage = transaction.objectForKey(page.permalink, inCollection: "pages") as? Page
                if persistedPage == nil || persistedPage!.modifiedTime.compare(page.modifiedTime) == .OrderedAscending {
                    transaction.setObject(page, forKey: page.permalink, inCollection: "pages")
                }
            })
        }
    }
    
    class func createFolder(folderPath: DBPath) {
        let fileInfo = DBFilesystem.sharedFilesystem().fileInfoForPath(folderPath, error: nil)
        if fileInfo == nil {
            DBFilesystem.sharedFilesystem().createFolder(folderPath, error: nil)
        }
    }
    
    func writeDefaultFile(name: String, ofType: String = "md", toPath: DBPath) {
        var error : DBError?
        if DBFilesystem.sharedFilesystem().openFile(toPath, error: &error) == nil {
            let defaultFilePath = NSBundle.mainBundle().pathForResource(name, ofType: ofType)
            let defaultFileContents = NSString(contentsOfFile: defaultFilePath!, encoding: NSUTF8StringEncoding, error: nil)
            let homeFile = DBFilesystem.sharedFilesystem().createFile(toPath, error: nil)
            homeFile.writeString(defaultFileContents as! String, error: nil)
        }
    }
    
    func files() -> [String] {
        var maybeError: DBError?
        if var files = DBFilesystem.sharedFilesystem().listFolder(Wiki.WIKI_PATH, error: &maybeError) as? [DBFileInfo] {
            let fileNames = files.filter({ (f: DBFileInfo) -> Bool in
                return !f.isFolder
            }).sorted({ (f1: DBFileInfo, f2: DBFileInfo) -> Bool in
                return f1.modifiedTime.laterDate(f2.modifiedTime) == f1.modifiedTime
            }).map {
                (fileInfo: DBFileInfo) -> String in
                return fileInfo.path.name()
            }
            return fileNames
        } else if let error = maybeError {
            println(error.localizedDescription)
        }
        return []
    }
    
    func isPage(permalink: String) -> Bool {
        let filePath = Wiki.WIKI_PATH.childPath(permalink + ".md")
        if let fileInfo = DBFilesystem.sharedFilesystem().fileInfoForPath(filePath, error: nil) {
            return true
        }
        return false
    }
    
    func page(permalink: String) -> Page? {
        let filePath = Wiki.WIKI_PATH.childPath(permalink + ".md")
        var maybeError: DBError?
        if let file = DBFilesystem.sharedFilesystem().openFile(filePath, error: &maybeError) {
            var content = file.readString(nil)
            if content == nil {
                content = ""
            }
            let page = Page(rawContent: content, filename: permalink, modifiedTime: file.info.modifiedTime, wiki: self)
            return page
        } else if let error = maybeError {
            println(error.localizedDescription)
        }
        return nil
    }
    
    func page(file: DBFile) -> Page? {
        let permalink = file.info.path.stringValue().lastPathComponent.stringByDeletingPathExtension
        var content = file.readString(nil)
        if content == nil {
            content = ""
        }
        let page = Page(rawContent: content, filename: permalink, modifiedTime: file.info.modifiedTime, wiki: self)
        return page
    }
    
    func delete(page: Page) {
        self.deleteFileFromDropbox(Wiki.WIKI_PATH.childPath(page.permalink + ".md"))
        self.deleteLocalFile(page.permalink + ".html")
    }
    
    func save(page: Page, overwrite: Bool = false) -> SaveResult {
        page.content = page.renderHTML(page.rawContent)
        let path = Wiki.WIKI_PATH.childPath(page.permalink + ".md")
        if let file = DBFilesystem.sharedFilesystem().createFile(path, error: nil) {
            file.writeString(page.rawContent, error: nil)
            self.persistToYapDatabase(file)
            return SaveResult.Success
        } else if overwrite {
            let file = DBFilesystem.sharedFilesystem().openFile(path, error: nil)
            file.writeString(page.rawContent, error: nil)
            self.persistToYapDatabase(file)
            return SaveResult.Success
        } else {
            return SaveResult.FileExists
        }
    }
    
    func saveImage(image: UIImage) -> String {
        var imageName = self.generateImageName()
        var imageFileName = imageName + ".jpg"
        var imageData = UIImageJPEGRepresentation(image, 0.5)
        
        self.writeImageToDropbox(imageFileName, data: imageData)
        self.writeLocalImage(imageFileName, data: imageData)
        
        return imageFileName
    }
    
    func generateImageName() -> String {
        var random = arc4random()
        var data = NSData(bytes: &random, length: 4)
        var base64String = data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(0))
        base64String = base64String.stringByReplacingOccurrencesOfString("=", withString: "")
        base64String = base64String.stringByReplacingOccurrencesOfString("+", withString: "_")
        base64String = base64String.stringByReplacingOccurrencesOfString("/", withString: "-")
        return base64String
    }
    
    func deleteFileFromDropbox(filePath: DBPath) {
        DBFilesystem.sharedFilesystem().deletePath(filePath, error: nil)
    }
    
    func writeImageToDropbox(fileName: String, data: NSData) {
        let imgFolderPath = Wiki.STATIC_PATH.childPath("img")
        DBFilesystem.sharedFilesystem().createFolder(imgFolderPath, error: nil)
        
        let imgPath = imgFolderPath.childPath(fileName)
        let file: DBFile = DBFilesystem.sharedFilesystem().createFile(imgPath, error: nil)
        file.writeData(data, error: nil)
    }

    func localImagePath(imageFileName: String) -> String {
        let fullPath = "www/img/\(imageFileName)"
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        return tmpPath
    }
    
    func copyFileToLocal(filePath: String, subfolder: String = "", overwrite: Bool = false) -> String? {
        let fullPath = "www/" + subfolder
        let fileMgr = NSFileManager.defaultManager()
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        var error: NSErrorPointer = nil
        if !fileMgr.createDirectoryAtPath(tmpPath, withIntermediateDirectories: true, attributes: nil, error: error) {
            println("Couldn't create www subdirectory. \(error)")
            return nil
        }
        let dstPath = tmpPath.stringByAppendingPathComponent(filePath.lastPathComponent)
        if !fileMgr.fileExistsAtPath(dstPath) {
            if !fileMgr.copyItemAtPath(filePath, toPath: dstPath, error: error) {
                println("Couldn't copy file to /tmp/\(fullPath). \(error)")
                return nil
            }
        } else if overwrite {
            fileMgr.removeItemAtPath(dstPath, error: nil)
            if !fileMgr.copyItemAtPath(filePath, toPath: dstPath, error: error) {
                println("Couldn't copy file to /tmp/\(fullPath). \(error)")
                return nil
            }
        }
        return dstPath
    }
    
    func deleteLocalFile(fileName: String, subfolder: String = "") {
        let fullPath = "www/" + subfolder
        let fileMgr = NSFileManager.defaultManager()
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        var error: NSErrorPointer = nil
        let dstPath = tmpPath.stringByAppendingPathComponent(fileName)
        if !fileMgr.removeItemAtPath(dstPath, error: error) {
            println("Couldn't delete \(dstPath) file. \(error)")
        }
    }
    
    func writeLocalFile(fileName: String, data: NSData, subfolder: String = "", overwrite: Bool = false) -> String? {
        if let basePath = self.localDestinationBasePath(subfolder: subfolder) {
            let dstPath = basePath.stringByAppendingPathComponent(fileName)
            let fileMgr = NSFileManager.defaultManager()
            if !fileMgr.fileExistsAtPath(dstPath) {
                if !fileMgr.createFileAtPath(dstPath, contents:data, attributes: nil) {
                    println("Couldn't copy file to \(basePath).")
                    return nil
                }
            } else if overwrite {
                fileMgr.removeItemAtPath(dstPath, error: nil)
                if !fileMgr.createFileAtPath(dstPath, contents:data, attributes: nil) {
                    println("Couldn't copy file to \(basePath).")
                    return nil
                }
            }
            return dstPath
        }
        return nil
    }
    
    func localFileExists(fileName: String, subfolder: String = "") -> Bool {
        if let basePath = self.localDestinationBasePath(subfolder: subfolder) {
            let dstPath = basePath.stringByAppendingPathComponent(fileName)
            let fileMgr = NSFileManager.defaultManager()
            return fileMgr.fileExistsAtPath(dstPath)
        }
        return false
    }
    
    func localImageExists(fileName: String) -> Bool {
        return self.localFileExists(fileName, subfolder: "img")
    }
    
    func localDestinationBasePath(subfolder: String = "") -> String? {
        let fullPath = "www/" + subfolder
        let fileMgr = NSFileManager.defaultManager()
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        var error: NSErrorPointer = nil
        if !fileMgr.createDirectoryAtPath(tmpPath, withIntermediateDirectories: true, attributes: nil, error: error) {
            println("Couldn't create \(fullPath) subdirectory. \(error)")
            return nil
        }
        return tmpPath
    }
    
    func writeLocalFile(fileName: String, content: String, subfolder: String = "", overwrite: Bool = false) -> String? {
        return self.writeLocalFile(
            fileName,
            data: content.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!,
            subfolder: subfolder,
            overwrite: overwrite
        )
    }
    
    func writeLocalImage(fileName: String, data: NSData) -> String? {
        return self.writeLocalFile(fileName, data: data, subfolder: "img")
    }
}