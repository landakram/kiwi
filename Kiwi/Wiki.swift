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
import FileKit

enum SaveResult {
    case success
    case fileExists
}


protocol Upgrade {
    func perform(wiki: Wiki)
}

struct FilesystemMigration: Upgrade {
    func perform(wiki: Wiki) {
        Async.background {
            print("-------------------")
            print("Starting migration to:")
            print(Path.userDocuments)
            print("-------------------")
            self.migrateFolder(path: DBPath.root())
        }
    }
    
    func migrateFolder(path: DBPath) {
        do {
            try Filesystem.sharedInstance.mkdir(path: Path.userDocuments + path.stringValue())
        }
        catch {
            print("errored trying to make /public");
        }
        self.migrateFiles(path: path)
    }
    
    func migrateFiles(path: DBPath) {
        if let files = DBFilesystem.shared().listFolder(path, error: nil) as? [DBFileInfo] {
            for info in files {
                print(info.path);
                if info.isFolder {
                    self.migrateFolder(path: info.path)
                } else {
                    self.migrateFile(info: info)
                }
            }
        }
    }
    
    func migrateFile(info: DBFileInfo) {
        if let file = DBFilesystem.shared().openFile(info.path, error: nil) {
            let path: Path = Path.userDocuments + info.path.stringValue()
            let content = file.readData(nil)
            let fsFile = File<Data>(path: path, contents: content! as Data)
            do {
                try Filesystem.sharedInstance.write(file: fsFile)
                try Filesystem.sharedInstance.touch(path: fsFile.path, modificationDate: info.modifiedTime)
            } catch {
                print("errored on (\(path))")
            }
        }
    }
}

class Wiki {
    static let WIKI_PATH: DBPath! = DBPath.root().childPath("wiki")
    static let STATIC_PATH: DBPath! = DBPath.root().childPath("public")
    
    static let IMG_PATH = Wiki.STATIC_PATH.childPath("img")
    static let STYLES_PATH = Wiki.STATIC_PATH.childPath("css")
    
    let upgrades: [Upgrade] = [FilesystemMigration()]
    
    init() {
        let defaultFolderPaths = [
            Wiki.WIKI_PATH,
            Wiki.STATIC_PATH,
            Wiki.IMG_PATH,
            Wiki.STYLES_PATH
        ]
        for folderPath in defaultFolderPaths {
            Wiki.createFolder(folderPath!)
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
                writeDefaultFile(permalink, ofType: "md", toPath: wikiPath!)
            }
            
            self.setLoadedFirstTime()
        }
        
        self.writeResouceFiles()
        // Copy images to local cache if they aren't already copied
        if let imgFiles = DBFilesystem.shared().listFolder(Wiki.IMG_PATH, error: nil) {
            for fileInfo in imgFiles {
                if let info = fileInfo as? DBFileInfo {
                    let filename = info.path.stringValue()
                    if !self.localImageExists(filename!) {
                        if let file = DBFilesystem.shared().openFile(info.path, error: nil) {
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
            DBFilesystem.shared().addObserver(self, forPathAndDescendants: Wiki.WIKI_PATH) {
                if !DBFilesystem.shared().status.download.inProgress {
                    Async.background {
                        self.syncUpdatedPagesToYapDatabase()
                    }
                }
            }
        }
        
        for upgrade in self.upgrades {
            upgrade.perform(wiki: self)
        }
    }
    
    deinit {
        DBFilesystem.shared().removeObserver(self)
    }
    
    func isLoadingForFirstTime() -> Bool {
        return !UserDefaults.standard.bool(forKey: "didLoadFirstTime")
    }
    
    func setLoadedFirstTime() {
        UserDefaults.standard.set(true, forKey: "didLoadFirstTime")
    }
    
    func writeResouceFiles() {
        let defaultJsFiles = [
            "links",
            "auto-render-latex.min",
            "prism",
            "jquery.min"
        ]
        for filename in defaultJsFiles {
            copyFileToLocal(Bundle.main.path(forResource: filename, ofType: "js")!)
        }
        
        let defaultCSSFiles = [
            "screen",
            "prism"
        ]
        for filename in defaultCSSFiles {
            copyFileToLocal(Bundle.main.path(forResource: filename, ofType: "css")!)
        }
    }
    
    func getAllFileInfos() -> [DBFileInfo]? {
        return DBFilesystem.shared().listFolder(Wiki.WIKI_PATH, error: nil) as? [DBFileInfo]
    }
    
    func syncUpdatedPagesToYapDatabase() {
        if let wikiFiles = getAllFileInfos() {
            for info in wikiFiles {
                if let file = DBFilesystem.shared().openFile(info.path, error: nil) {
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
    
    func persistToYapDatabase(_ file: DBFile) {
        if let page = self.page(file) {
            let connection = Yap.sharedInstance.newConnection()
            connection.readWrite({ (transaction: YapDatabaseReadWriteTransaction!) in
                let pageCoder = transaction.object(forKey: page.permalink, inCollection: "pages") as? PageCoder
                if pageCoder == nil || pageCoder!.page.modifiedTime.compare(page.modifiedTime as Date) == .orderedAscending {
                    transaction.setObject(PageCoder(page: page), forKey: page.permalink, inCollection: "pages")
                }
            })
        }
    }
    
    class func createFolder(_ folderPath: DBPath) {
        let fileInfo = DBFilesystem.shared().fileInfo(for: folderPath, error: nil)
        if fileInfo == nil {
            DBFilesystem.shared().createFolder(folderPath, error: nil)
        }
    }
    
    func writeDefaultFile(_ name: String, ofType: String = "md", toPath: DBPath) {
        var error : DBError?
        if DBFilesystem.shared().openFile(toPath, error: &error) == nil {
            let defaultFilePath = Bundle.main.path(forResource: name, ofType: ofType)
            let defaultFileContents = try? NSString(contentsOfFile: defaultFilePath!, encoding: String.Encoding.utf8.rawValue)
            let homeFile = DBFilesystem.shared().createFile(toPath, error: nil)
            homeFile?.write(defaultFileContents as! String, error: nil)
        }
    }
    
    func files() -> [String] {
        var maybeError: DBError?
        if let files = DBFilesystem.shared().listFolder(Wiki.WIKI_PATH, error: &maybeError) as? [DBFileInfo] {
            let fileNames = files.filter({ (f: DBFileInfo) -> Bool in
                return !f.isFolder
            }).sorted(by: { (f1: DBFileInfo, f2: DBFileInfo) -> Bool in
                return f1.modifiedTime > f2.modifiedTime
            }).map {
                (fileInfo: DBFileInfo) -> String in
                return fileInfo.path.name()
            }
            return fileNames
        } else if let error = maybeError {
            print(error.localizedDescription)
        }
        return []
    }
    
    static func isPage(_ permalink: String) -> Bool {
        let filePath = Wiki.WIKI_PATH.childPath(permalink + ".md")
        if let fileInfo = DBFilesystem.shared().fileInfo(for: filePath, error: nil) {
            return true
        }
        return false
    }
    
    func isPage(_ permalink: String) -> Bool {
        return Wiki.isPage(permalink)
    }
    
    func page(_ permalink: String) -> Page? {
        let filePath = Wiki.WIKI_PATH.childPath(permalink + ".md")
        var maybeError: DBError?
        if let file = DBFilesystem.shared().openFile(filePath, error: &maybeError) {
            return page(file)
        } else if let error = maybeError {
            print(error.localizedDescription)
        }
        return nil
    }
    
    func page(_ file: DBFile) -> Page? {
        let permalink = file.info.path.stringValue().lastPathComponent.stringByDeletingPathExtension
        var content = file.readString(nil)
        if content == nil {
            content = ""
        }
        let page = Page(rawContent: content!,
                        permalink: permalink,
                        name: Page.permalinkToName(permalink: permalink),
                        modifiedTime: file.info.modifiedTime,
                        createdTime: file.info.modifiedTime,
                        isDirty: false)
        return page
    }
    
    func delete(_ page: Page) {
        self.deleteFileFromDropbox(Wiki.WIKI_PATH.childPath(page.permalink + ".md"))
        self.deleteLocalFile(page.permalink + ".html")
    }
    
    func save(_ page: Page, overwrite: Bool = false) -> SaveResult {
        let path = Wiki.WIKI_PATH.childPath(page.permalink + ".md")
        if let file = DBFilesystem.shared().createFile(path, error: nil) {
            file.write(page.rawContent, error: nil)
            self.persistToYapDatabase(file)
            return SaveResult.success
        } else if overwrite {
            if let file = DBFilesystem.shared().openFile(path, error: nil) {
                file.write(page.rawContent, error: nil)
                self.persistToYapDatabase(file)
            }
            return SaveResult.success
        } else {
            return SaveResult.fileExists
        }
    }
    
    func saveImage(_ image: UIImage) -> String {
        let imageName = self.generateImageName()
        let imageFileName = imageName + ".jpg"
        let imageData = UIImageJPEGRepresentation(image, 0.5)
        
        self.writeImageToDropbox(imageFileName, data: imageData!)
        self.writeLocalImage(imageFileName, data: imageData!)
        
        return imageFileName
    }
    
    func generateImageName() -> String {
        let length = 6
        
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for _ in (0..<length) {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let newCharacter = allowedChars[allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)]
            randomString += String(newCharacter)
        }
        
        return randomString
    }
    
    func deleteFileFromDropbox(_ filePath: DBPath) {
        DBFilesystem.shared().delete(filePath, error: nil)
    }
    
    func writeImageToDropbox(_ fileName: String, data: Data) {
        let imgFolderPath = Wiki.STATIC_PATH.childPath("img")
        DBFilesystem.shared().createFolder(imgFolderPath, error: nil)
        
        let imgPath = imgFolderPath?.childPath(fileName)
        let file: DBFile = DBFilesystem.shared().createFile(imgPath, error: nil)
        file.write(data, error: nil)
    }

    func localImagePath(_ imageFileName: String) -> String {
        let fullPath = "www/img/\(imageFileName)"
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        return tmpPath
    }
    
    func copyFileToLocal(_ filePath: String, subfolder: String = "", overwrite: Bool = false) -> String? {
        let fullPath = "www/" + subfolder
        let fileMgr = FileManager.default
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        let error: NSErrorPointer? = nil
        do {
            try fileMgr.createDirectory(atPath: tmpPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error1 as NSError {
            error??.pointee = error1
            print("Couldn't create www subdirectory. \(error)")
            return nil
        }
        let dstPath = tmpPath.stringByAppendingPathComponent(filePath.lastPathComponent)
        if !fileMgr.fileExists(atPath: dstPath) {
            do {
                try fileMgr.copyItem(atPath: filePath, toPath: dstPath)
            } catch let error1 as NSError {
                error??.pointee = error1
                print("Couldn't copy file to /tmp/\(fullPath). \(error)")
                return nil
            }
        } else if overwrite {
            do {
                try fileMgr.removeItem(atPath: dstPath)
            } catch _ {
            }
            do {
                try fileMgr.copyItem(atPath: filePath, toPath: dstPath)
            } catch let error1 as NSError {
                error??.pointee = error1
                print("Couldn't copy file to /tmp/\(fullPath). \(error)")
                return nil
            }
        }
        return dstPath
    }
    
    func deleteLocalFile(_ fileName: String, subfolder: String = "") {
        let fullPath = "www/" + subfolder
        let fileMgr = FileManager.default
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        let error: NSErrorPointer? = nil
        let dstPath = tmpPath.stringByAppendingPathComponent(fileName)
        do {
            try fileMgr.removeItem(atPath: dstPath)
        } catch let error1 as NSError {
            error??.pointee = error1
            print("Couldn't delete \(dstPath) file. \(error)")
        }
    }
    
    func writeLocalFile(_ fileName: String, data: Data, subfolder: String = "", overwrite: Bool = false) -> String? {
        if let basePath = self.localDestinationBasePath(subfolder) {
            let dstPath = basePath.stringByAppendingPathComponent(fileName)
            let fileMgr = FileManager.default
            if !fileMgr.fileExists(atPath: dstPath) {
                if !fileMgr.createFile(atPath: dstPath, contents:data, attributes: nil) {
                    print("Couldn't copy file to \(basePath).")
                    return nil
                }
            } else if overwrite {
                do {
                    try fileMgr.removeItem(atPath: dstPath)
                } catch _ {
                }
                if !fileMgr.createFile(atPath: dstPath, contents:data, attributes: nil) {
                    print("Couldn't copy file to \(basePath).")
                    return nil
                }
            }
            return dstPath
        }
        return nil
    }
    
    func localFileExists(_ fileName: String, subfolder: String = "") -> Bool {
        if let basePath = self.localDestinationBasePath(subfolder) {
            let dstPath = basePath.stringByAppendingPathComponent(fileName)
            let fileMgr = FileManager.default
            return fileMgr.fileExists(atPath: dstPath)
        }
        return false
    }
    
    func localImageExists(_ fileName: String) -> Bool {
        return self.localFileExists(fileName, subfolder: "img")
    }
    
    func localDestinationBasePath(_ subfolder: String = "") -> String? {
        let fullPath = "www/" + subfolder
        let fileMgr = FileManager.default
        let tmpPath = NSTemporaryDirectory().stringByAppendingPathComponent(fullPath)
        let error: NSErrorPointer? = nil
        do {
            try fileMgr.createDirectory(atPath: tmpPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error1 as NSError {
            error??.pointee = error1
            print("Couldn't create \(fullPath) subdirectory. \(error)")
            return nil
        }
        return tmpPath
    }
    
    func writeLocalFile(_ fileName: String, content: String, subfolder: String = "", overwrite: Bool = false) -> String? {
        return self.writeLocalFile(
            fileName,
            data: content.data(using: String.Encoding.utf8, allowLossyConversion: false)!,
            subfolder: subfolder,
            overwrite: overwrite
        )
    }
    
    func writeLocalImage(_ fileName: String, data: Data) -> String? {
        return self.writeLocalFile(fileName, data: data, subfolder: "img")
    }
}
