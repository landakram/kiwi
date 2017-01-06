//
//  SyncEngine.swift
//  Kiwi
//
//  Created by Mark Hudnall on 11/7/16.
//  Copyright © 2016 Mark Hudnall. All rights reserved.
//

import Foundation
import EmitterKit
import FileKit
import Async

class SyncEngine {
    static let sharedInstance = SyncEngine()
    
    let local: Filesystem
    let remote: DropboxRemote
    var dirtyStore: DirtyStore = DirtyStore()
    
    var localEventListener: EventListener<FilesystemEvent>!
    var remoteEventListener: EventListener<FilesystemEvent>!
    
    init(local: Filesystem = Filesystem.sharedInstance, remote: DropboxRemote = DropboxRemote.sharedInstance) {
        self.local = local
        self.remote = remote
        self.start()
    }
    
    func start() {
        self.localEventListener = self.local.event.on { (event: FilesystemEvent) in
            switch event {
            case .delete(let path):
                // The path may be absolute, so we need to translate to a relative path
                // that is in common with the remote filesystem.
                // 
                // i.e. it might be /usr/docs/wiki/page.md
                // where /usr/docs/ is specific to this platform.
                let relativePath = path.relativeTo(self.local.root)
                self.dirtyStore.add(path: relativePath)
                do {
                    try self.push(event: .delete(path: relativePath))
                    self.dirtyStore.remove(path: path)
                } catch {
                    
                }
            case .write(let path):
                let relativePath = path.relativeTo(self.local.root)
                self.dirtyStore.add(path: path)
                do {
                    try self.push(event: .write(path: relativePath))
                    self.dirtyStore.remove(path: path)
                } catch {
                    
                }
            }
        }
    
        self.remoteEventListener = self.remote.event.on { (event: FilesystemEvent) in
            print("remote event: \(event)")
            self.pull(event: event)
        }
    }
    
    func stop() {
        self.localEventListener.isListening = false
        self.remoteEventListener.isListening = false
    }
    
    func push(event: FilesystemEvent) throws {
        switch event {
        case .delete(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers our version.
            try self.remote.delete(path: path)
        case .write(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers our version.
            let file: File<Data> = try! self.local.read(path: path)
            // The path may be absolute, so we need to translate to a relative path
            // that is in common with the remote filesystem.
            //
            // i.e. it might be /usr/docs/wiki/page.md
            // where /usr/docs/ is specific to this platform.
            try self.remote.write(file: File(path: file.path.relativeTo(self.local.root), contents: file.contents))
        }
    }
    
    func pull(event: FilesystemEvent) {
        switch event {
        case .delete(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers their version.
            try! self.local.delete(path: path)
        case .write(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers their version.
            let file: File<Data> = try! self.remote.read(path: path)
            guard let localFile: File<Data> = try? self.local.read(path: path) else {
                try! self.local.write(file: file)
                return
            }
            if file.contents != localFile.contents {
                try! self.local.write(file: file)
            }
        }
    }
    
    func sweep() {
        for path in self.dirtyStore.all() {
            if self.local.exists(path: path) {
                do {
                    let file: File<Data> = try self.local.read(path: path)
                    try self.push(event: .write(path: path))
                    self.dirtyStore.remove(path: path)
                } catch {
                    
                }
            } else {
                do {
                    try self.push(event: .delete(path: path))
                    self.dirtyStore.remove(path: path)
                } catch {
                    
                }
            }
        }
    }
}

/**
 * Tracks the dirty state of paths in the local filesystem.
 */
struct DirtyStore {
    var backingSet: Set<Path> = Set<Path>()
    
    mutating func add(path: Path) {
        backingSet.insert(path)
    }
    
    mutating func remove(path: Path) {
        backingSet.remove(path)
    }
    
    func has(path: Path) -> Bool {
        return backingSet.contains(path)
    }
    
    func all() -> [Path] {
        return self.backingSet.sorted(by: { (first: Path, second: Path) -> Bool in
            return true
        })
    }
}

enum RemoteError: Error {
    case WriteError(file: File<Data>)
    case ReadError(path: Path)
}

class DropboxRemote {
    static let sharedInstance = DropboxRemote()
    let event: Event<FilesystemEvent> = Event();
    
    let rootPath = DBPath.root()
    var filesystem: DBFilesystem!
    
    init(filesystem: DBFilesystem? = nil) {
        self.filesystem = filesystem
    }
    
    func configure(filesystem: DBFilesystem) {
        self.filesystem = filesystem
    }
    
    func start() {
        self.filesystem.addObserver(self, forPathAndDescendants: self.rootPath) {
            if !DBFilesystem.shared().status.download.inProgress {
                Async.background {
                    self.syncUpdatedFiles(path: self.rootPath!)
                }
            }
        }
    }
    
    func write(file: File<Data>) throws {
        let path = DBPath(string: file.path.rawValue)
        if let remoteFile = self.filesystem.createFile(path, error: nil) {
            remoteFile.write(file.contents, error: nil)
        } else if let remoteFile = self.filesystem.openFile(path, error: nil) {
            remoteFile.write(file.contents, error: nil)
        } else {
            throw RemoteError.WriteError(file: file)
        }
    }
    
    func delete<T: ReadableWritable>(file: File<T>) throws {
        try self.delete(path: file.path)
    }
    
    func delete(path: Path) throws {
        let path = DBPath(string: path.rawValue)
        self.filesystem.delete(path, error: nil)
    }
    
    func read(path: Path) throws -> File<Data> {
        let remotePath = DBPath(string: path.rawValue)
        if let file = DBFilesystem.shared().openFile(remotePath, error: nil) {
            let content = file.readData(nil)
            let fsFile = File<Data>(path: path, modifiedDate: file.info.modifiedTime, contents: content! as Data)
            return fsFile
        }
        throw RemoteError.ReadError(path: path)
    }
    
    func list(path: Path) -> [Path] {
        let path = DBPath(string: path.rawValue)
        if let fileInfos = DBFilesystem.shared().listFolder(path, error: nil) as? [DBFileInfo] {
            let filePaths = fileInfos.map({ (fileInfo) -> Path in
                return Path(fileInfo.path.stringValue())
            })
            return filePaths
        } else {
            return []
        }
    }
    
    func crawl() {
        
        self.syncUpdatedFiles(path: self.rootPath!, read: true)
    }
    
    func syncUpdatedFiles(path: DBPath, read: Bool = false) {
        if let files = self.filesystem.listFolder(path, error: nil) as? [DBFileInfo] {
            for info in files {
                if info.isFolder {
                    self.syncUpdatedFiles(path: info.path, read: read)
                } else {
                    if let file = DBFilesystem.shared().openFile(info.path, error: nil) {
                        if read {
                            file.readHandle(nil)
                        }
                        if !file.status.cached {
                            file.addObserver(self, block: {
                                if file.status.cached {
                                    file.removeObserver(self)
                                    file.close()
                                    self.event.emit(FilesystemEvent.write(path: Path(info.path.stringValue())))
                                }
                            })
                        } else {
                            file.close()
                            self.event.emit(FilesystemEvent.write(path: Path(info.path.stringValue())))
                        }
                    }
                }
            }
        }
    }
}

extension Path {
    /**
     If the path is a child of `otherPath`, returns it as a relative path.
     Otherwise, returns the path as is.
    */
    func relativeTo(_ otherPath: Path) -> Path {
        if self.commonAncestor(otherPath) == otherPath {
            let selfComponents = self.components
            let relativeComponents = selfComponents[otherPath.components.count ..< selfComponents.count]
            return relativeComponents.reduce("") { $0 + $1 }

        }
        return self
    }
}
