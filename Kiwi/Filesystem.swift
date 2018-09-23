//
//  Filesystem.swift
//  Kiwi
//
//  Created by Mark Hudnall on 11/7/16.
//  Copyright © 2016 Mark Hudnall. All rights reserved.
//

import Foundation
import class FileKit.File
import struct FileKit.Path
import protocol FileKit.Readable
import protocol FileKit.Writable
import RxSwift

typealias Path = FileKit.Path
typealias ReadableWritable = FileKit.Readable & FileKit.Writable
typealias FileKitFile = FileKit.File

protocol EventedFilesystem {
    var events: Observable<FilesystemEvent> { get }
    var root: Path { get }
    func list(path: Path) -> [Path]
    func read<T: ReadableWritable>(path: Path) throws -> File<T>
    func mkdir(path: Path) throws
    func exists(path: Path) -> Bool
    func write<T: ReadableWritable>(file: File<T>, emit: Bool) throws
    func delete<T: ReadableWritable>(file: File<T>, emit: Bool) throws
    func delete(path: Path, emit: Bool) throws
    func touch(path: Path, modificationDate: Date) throws
}

struct Filesystem: EventedFilesystem {
    static let sharedInstance = Filesystem()
    
    private let disposeBag: DisposeBag = DisposeBag()
    
    var events: Observable<FilesystemEvent> {
        get {
            return self.subject.asObservable()
        }
    }
    private var subject: ReplaySubject<FilesystemEvent> = ReplaySubject.createUnbounded()

    let root: Path
    
    init(root: Path = Path.userDocuments) {
        self.root = root
    }
    
    private func fromRoot(_ path: Path) -> Path {
        // If root is the common ancestor, then the path has already been resolved
        if (self.root.commonAncestor(path) == self.root) {
            return path
        }
        return self.root + path
    }
    
    func list(path: Path) -> [Path] {
        let path = fromRoot(path)
        return path.children()
    }
    
    func read<T: ReadableWritable>(path: Path) throws -> File<T> {
        let realFile = FileKitFile<T>(path: fromRoot(path))
        let contents = try realFile.read()
        let absPath = fromRoot(path)
        return File(path: absPath, modifiedDate: absPath.modificationDate, contents: contents)
    }
    
    func mkdir(path: Path) throws {
        print("mkdir \(path)")
        try fromRoot(path).createDirectory()
    }
    
    func exists(path: Path) -> Bool {
        return fromRoot(path).exists
    }
    
    func write<T: ReadableWritable>(file: File<T>, emit: Bool = true) throws {
        print("write \(file.path)")
        let realFile = FileKitFile<T>(path: fromRoot(file.path))
        try realFile.write(file.contents)
        if ((file.modifiedDate) != nil) {
            realFile.path.modificationDate = file.modifiedDate   
        }
        if emit {
            self.subject.onNext(.write(path: file.path))
        }
    }
    
    func delete<T: ReadableWritable>(file: File<T>, emit: Bool = true) throws {
        try self.delete(path: file.path, emit: emit)
    }
    
    func delete(path: Path, emit: Bool = true) throws {
        print("delete \(path)")
        try fromRoot(path).deleteFile()
        if emit {
            self.subject.onNext(.delete(path: path))
        }
    }
    
    func touch(path: Path, modificationDate: Date = Date()) throws {
        print("touch \(path)")
        try fromRoot(path).touch(modificationDate: modificationDate)
    }
}

struct File<T: ReadableWritable> {
    var path: Path
    var _modifiedDate: Date?
    var modifiedDate: Date? {
        get {
            return _modifiedDate
        }
        set {
            _modifiedDate = newValue
            if (_modifiedDate != nil) {
                path.modificationDate = _modifiedDate
            }
        }
    }
    var contents: T
    
    init(path: Path, modifiedDate: Date? = nil, contents: T) {
        self.path = path
        self.contents = contents
        self.modifiedDate = modifiedDate ?? path.modificationDate
    }
}

enum FilesystemEvent {
    case write(path: Path)
    case delete(path: Path)
}

// Path functions

func + (lhs: Path, rhs: Path) -> Path {
    if lhs.rawValue.isEmpty || lhs.rawValue == "." { return rhs }
    if rhs.rawValue.isEmpty || rhs.rawValue == "." { return lhs }
    switch (lhs.rawValue.hasSuffix(Path.separator), rhs.rawValue.hasPrefix(Path.separator)) {
    case (true, true):
        let rhsRawValue = rhs.rawValue.dropFirst()
        return Path("\(lhs.rawValue)\(rhsRawValue)")
    case (false, false):
        return Path("\(lhs.rawValue)\(Path.separator)\(rhs.rawValue)")
    default:
        return Path("\(lhs.rawValue)\(rhs.rawValue)")
    }
}

/// Converts a `String` to a `Path` and returns the concatenated result.

func + (lhs: String, rhs: Path) -> Path {
    return Path(lhs) + rhs
}

/// Converts a `String` to a `Path` and returns the concatenated result.

func + (lhs: Path, rhs: String) -> Path {
    return lhs + Path(rhs)
}
