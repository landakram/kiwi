//
//  Filesystem.swift
//  Kiwi
//
//  Created by Mark Hudnall on 11/7/16.
//  Copyright © 2016 Mark Hudnall. All rights reserved.
//

import Foundation
import FileKit
import EmitterKit

typealias Path = FileKit.Path

struct Filesystem {
    static let sharedInstance = Filesystem()
    
    let event: Event<FilesystemEvent> = Event();
    
    func mkdir(path: Path) throws {
        try path.createDirectory()
    }
    
    func write<T: ReadableWritable>(file: File<T>) throws {
        let realFile = FileKit.File<T>(path: file.path)
        try realFile.write(file.contents)
        event.emit(.write(path: file.path))
    }
    
    func delete<T: ReadableWritable>(file: File<T>) throws {
        try self.delete(path: file.path)
    }
    
    func delete(path: Path) throws {
        try path.deleteFile()
        event.emit(.delete(path: path))
    }
    
    func touch(path: Path, modificationDate: Date = Date()) throws {
        try path.touch(modificationDate: modificationDate)
    }
}

struct File<T: ReadableWritable> {
    let path: Path
    var contents: T
}

enum FilesystemEvent {
    case write(path: Path)
    case delete(path: Path)
}

