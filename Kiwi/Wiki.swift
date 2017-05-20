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

class Wiki {
    static let WIKI_PATH: Path = Path("wiki")
    static let STATIC_PATH: Path = Path("public")
    
    static let IMG_PATH = Wiki.STATIC_PATH + Path("img")
    static let STYLES_PATH = Wiki.STATIC_PATH + Path("css")
    
    let filesystem: Filesystem
    let indexer: Indexer
    
    
    init(filesystem: Filesystem = Filesystem.sharedInstance, indexer: Indexer = Indexer.sharedInstance) {
        self.filesystem = filesystem
        self.indexer = indexer
        
        print("-------------------")
        print("Wiki location:")
        print(self.filesystem.root)
        print("-------------------")
    }
    
    func scaffold() {
        let defaultFolderPaths = [
            Wiki.WIKI_PATH,
            Wiki.STATIC_PATH,
            Wiki.IMG_PATH,
            Wiki.STYLES_PATH
        ]
        
        for folderPath in defaultFolderPaths {
            try? self.filesystem.mkdir(path: folderPath)
        }
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
            return toPage(file)
        } else {
            return nil
        }
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


func toPage(_ file: File<String>) -> Page? {
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
