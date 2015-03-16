//
//  Wiki.swift
//  Memex
//
//  Created by Mark Hudnall on 3/3/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import Foundation

enum SaveResult {
    case Success
    case FileExists
}

class Wiki {
    let WIKI_PATH = DBPath.root().childPath("wiki")
    let STATIC_PATH = DBPath.root().childPath("public")
    let IMG_PATH: DBPath!
    let STYLES_PATH: DBPath!
    
    init() {
        createFolder(self.WIKI_PATH)
        createFolder(self.STATIC_PATH)
        
        self.IMG_PATH = self.STATIC_PATH.childPath("img")
        self.STYLES_PATH = self.STATIC_PATH.childPath("css")
        createFolder(self.IMG_PATH)
        createFolder(self.STYLES_PATH)
        
        // Write default files if they don't already exist
        let homePath = self.WIKI_PATH.childPath("home.md")
        let sampleArticlePath = self.WIKI_PATH.childPath("markdown_test.md")
        writeDefaultFile("home", ofType: "md", toPath: homePath)
        writeDefaultFile("markdown_test", ofType: "md", toPath: sampleArticlePath)
        
        writeDefaultFile("screen", ofType: "css", toPath: self.STYLES_PATH.childPath("screen.css"))
        
        // Copy images to local cache if they aren't already copied
        if let imgFiles = DBFilesystem.sharedFilesystem().listFolder(self.IMG_PATH, error: nil) {
            for fileInfo in imgFiles {
                if let info = fileInfo as? DBFileInfo {
                    let file = DBFilesystem.sharedFilesystem().openFile(info.path, error: nil)
                    if !file.status.cached {
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
    
    func createFolder(folderPath: DBPath) {
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
            homeFile.writeString(defaultFileContents, error: nil)
        }
    }
    
    func files() -> [String] {
        var maybeError: DBError?
        if var files = DBFilesystem.sharedFilesystem().listFolder(self.WIKI_PATH, error: &maybeError) as? [DBFileInfo] {
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
        let filePath = self.WIKI_PATH.childPath(permalink + ".md")
        if let fileInfo = DBFilesystem.sharedFilesystem().fileInfoForPath(filePath, error: nil) {
            return true
        }
        return false
    }
    
    func page(permalink: String) -> Page? {
        let filePath = self.WIKI_PATH.childPath(permalink + ".md")
        var maybeError: DBError?
        if let file = DBFilesystem.sharedFilesystem().openFile(filePath, error: &maybeError) {
            var content = file.readString(nil)
            if content == nil {
                content = ""
            }
            let page = Page(rawContent: content, filename: permalink, wiki: self)
            return page
        } else if let error = maybeError {
            println(error.localizedDescription)
        }
        return nil
    }
    
    func delete(page: Page) {
        self.deleteFileFromDropbox(self.WIKI_PATH.childPath(page.permalink + ".md"))
        self.deleteLocalFile(page.permalink + ".html")
    }
    
    func save(page: Page, overwrite: Bool = false) -> SaveResult {
        page.content = page.renderHTML(page.rawContent)
        let path = self.WIKI_PATH.childPath(page.permalink + ".md")
        if let file = DBFilesystem.sharedFilesystem().createFile(path, error: nil) {
            file.writeString(page.rawContent, error: nil)
            return SaveResult.Success
        } else if overwrite {
            let file = DBFilesystem.sharedFilesystem().openFile(path, error: nil)
            file.writeString(page.rawContent, error: nil)
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
        let imgFolderPath = self.STATIC_PATH.childPath("img")
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
        let fullPath = "www/" + subfolder
        let fileMgr = NSFileManager.defaultManager()
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        var error: NSErrorPointer = nil
        if !fileMgr.createDirectoryAtPath(tmpPath, withIntermediateDirectories: true, attributes: nil, error: error) {
            println("Couldn't create \(fullPath) subdirectory. \(error)")
            return nil
        }
        let dstPath = tmpPath.stringByAppendingPathComponent(fileName)
        if !fileMgr.fileExistsAtPath(dstPath) {
            if !fileMgr.createFileAtPath(dstPath, contents:data, attributes: nil) {
                println("Couldn't copy file to /tmp/\(fullPath). \(error)")
                return nil
            }
        } else if overwrite {
            fileMgr.removeItemAtPath(dstPath, error: nil)
            if !fileMgr.createFileAtPath(dstPath, contents:data, attributes: nil) {
                println("Couldn't copy file to /tmp/\(fullPath). \(error)")
                return nil
            }
        }
        return dstPath
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