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
    let filesystem: Filesystem = Filesystem.sharedInstance
    
    func perform(wiki: Wiki) {
        Async.background {
            print("-------------------")
            print("Starting migration to:")
            print(self.filesystem.root)
            print("-------------------")
            self.migrateFolder(path: DBPath.root())
        }
    }
    
    func migrateFolder(path: DBPath) {
        do {
            try self.filesystem.mkdir(path: Path(path.stringValue()))
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
            let path: Path = Path(info.path.stringValue())
            let content = file.readData(nil)
            let fsFile = File<Data>(path: path, contents: content! as Data)
            do {
                try self.filesystem.write(file: fsFile)
                try self.filesystem.touch(path: fsFile.path, modificationDate: info.modifiedTime)
            } catch {
                print("errored on (\(path))")
            }
        }
    }
}

class Wiki {
    static let WIKI_PATH: Path = Path("wiki")
    static let STATIC_PATH: Path = Path("public")
    
    static let IMG_PATH = Wiki.STATIC_PATH + Path("img")
    static let STYLES_PATH = Wiki.STATIC_PATH + Path("css")
    
    let upgrades: [Upgrade] = [FilesystemMigration()]
    let filesystem: Filesystem = Filesystem.sharedInstance
    
    init() {
        let defaultFolderPaths = [
            Wiki.WIKI_PATH,
            Wiki.STATIC_PATH,
            Wiki.IMG_PATH,
            Wiki.STYLES_PATH
        ]
        
        for folderPath in defaultFolderPaths {
            try? self.filesystem.mkdir(path: folderPath)
        }
        
        if (self.isLoadingForFirstTime()) {
            self.writeDefaultFiles()
            self.setLoadedFirstTime()
        }
        
        // TODO: these are related to actually rendering the wiki as HTML
        self.writeResouceFiles()
        self.copyImagesToLocalCache()

        for upgrade in self.upgrades {
            upgrade.perform(wiki: self)
        }
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
    
//    func persistToYapDatabase(_ file: DBFile) {
//        if let page = self.page(file) {
//            let connection = Yap.sharedInstance.newConnection()
//            connection.readWrite({ (transaction: YapDatabaseReadWriteTransaction!) in
//                let pageCoder = transaction.object(forKey: page.permalink, inCollection: "pages") as? PageCoder
//                if pageCoder == nil || pageCoder!.page.modifiedTime.compare(page.modifiedTime as Date) == .orderedAscending {
//                    transaction.setObject(PageCoder(page: page), forKey: page.permalink, inCollection: "pages")
//                }
//            })
//        }
//    }

    func files() -> [String] {
        let files = self.filesystem.list(path: Wiki.WIKI_PATH)
        return files.filter({ (path: Path) -> Bool in
            return !path.isDirectory
        }).sorted(by: { (path1, path2) -> Bool in
            if path1.modificationDate == nil || path2.modificationDate == nil {
                return true
            } else {
                return path1.modificationDate! > path2.modificationDate!
            }
        }).map({ (path: Path) -> String in
            return path.fileName
        })
    }
    
    static func isPage(_ permalink: String) -> Bool {
        let filePath = Wiki.WIKI_PATH + Path(permalink + ".md")
        return Filesystem.sharedInstance.exists(path: filePath)
    }
    
    func isPage(_ permalink: String) -> Bool {
        return Wiki.isPage(permalink)
    }
    
    func page(_ permalink: String) -> Page? {
        let path = Wiki.WIKI_PATH  + Path(permalink + ".md")
        if let file: File<String> = try? self.filesystem.read(path: path) {
            return page(file)
        } else {
            return nil
        }
    }
    
    func page(_ file: File<String>) -> Page? {
        let permalink = file.path.fileName.stringByDeletingPathExtension
        var content = file.contents
        let page = Page(rawContent: content,
                        permalink: permalink,
                        name: Page.permalinkToName(permalink: permalink),
                        modifiedTime: file.path.modificationDate!,
                        createdTime: file.path.modificationDate!,
                        isDirty: false)
        return page
    }
    
    func delete(_ page: Page) {
        let path = Wiki.WIKI_PATH + Path(page.permalink + ".md")
        try? self.filesystem.delete(path: path)
    }
    
    func save(_ page: Page, overwrite: Bool = false) -> SaveResult {
        let path = Wiki.WIKI_PATH + Path(page.permalink + ".md")
        if !self.filesystem.exists(path: path) || overwrite {
            let file: File<String> = File(path: path, contents: page.rawContent)
            do {
                try self.filesystem.write(file: file)
                return .success
            } catch {
                // TODO: really this should be some other unknown error
                return .fileExists
            }
        } else {
            return .fileExists
        }
    }
    
    func saveImage(_ image: UIImage) -> String {
        let imageName = self.generateImageName()
        let imageFileName = imageName + ".jpg"
        let imageData = UIImageJPEGRepresentation(image, 0.5)
        
        self.writeImageToFilesystem(imageFileName, data: imageData!)
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
    
    func writeImageToFilesystem(_ fileName: String, data: Data) {
        let imgFolderPath = Wiki.STATIC_PATH + Path("img")
        if !self.filesystem.exists(path: imgFolderPath) {
            try! self.filesystem.mkdir(path: imgFolderPath)
        }
        
        let imgPath = imgFolderPath + Path(fileName)
        let file: File<Data> = File(path: imgPath, contents: data)
        try! self.filesystem.write(file: file)
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
    
    func writeDefaultFiles() {
        let defaultPages = [
            "home",
            "working_with_pages",
            "writing_with_kiwi",
            "acknowledgements",
            "available_in_dropbox"
        ]
        for pageName in defaultPages {
            let path = Wiki.WIKI_PATH + Path(pageName + ".md")
            if !self.filesystem.exists(path: path) {
                let defaultFilePath = Bundle.main.path(forResource: pageName, ofType: "md")
                let defaultFileContents = try! NSString(contentsOfFile: defaultFilePath!, encoding: String.Encoding.utf8.rawValue) as String
                let defaultFile = File(path: path, contents: defaultFileContents)
                try? self.filesystem.write(file: defaultFile)
            }
        }
    }
    
    func copyImagesToLocalCache() {
        let imgFiles = self.filesystem.list(path: Wiki.IMG_PATH)
        for path in imgFiles {
            let filename = path.fileName
            let file: File<Data> = try! self.filesystem.read(path: path)
            self.writeLocalImage(filename, data: file.contents)
        }
    }
}
