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
import SwiftyDropbox
import BrightFutures
import Result

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
                self.push(event: .delete(path: relativePath)).onSuccess(callback: { (_) in
                    self.dirtyStore.remove(path: path)
                })
                // TODO: Do I need to do error handling of the above?
            case .write(let path):
                let relativePath = path.relativeTo(self.local.root)
                self.dirtyStore.add(path: path)
                self.push(event: .write(path: relativePath)).onSuccess(callback: { (_) in
                    self.dirtyStore.remove(path: path)
                })
                // TODO: Do I need to do error handling of the above?
            }
        }
        
//        self.remoteEventListener = self.remote.bufferredEvents.on { (events: Array<FilesystemEvent>) in
//            events.map(self.pull)
//        }
    
        self.remoteEventListener = self.remote.event.on { (event: FilesystemEvent) in
            print("remote event: \(event)")
            self.pull(event: event)
        }
    }
    
    func stop() {
        self.localEventListener.isListening = false
        self.remoteEventListener.isListening = false
    }
    
    func push(event: FilesystemEvent) -> Future<Path, RemoteError> {
        switch event {
        case .delete(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers our version.
            return self.remote.delete(path: path)
        case .write(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers our version.
            let file: File<Data> = try! self.local.read(path: path)
            // The path may be absolute, so we need to translate to a relative path
            // that is in common with the remote filesystem.
            //
            // i.e. it might be /usr/docs/wiki/page.md
            // where /usr/docs/ is specific to this platform.
            return self.remote.write(file: File(path: file.path.relativeTo(self.local.root), contents: file.contents))
        }
    }
    
    func pull(event: FilesystemEvent) -> Future<Path, RemoteError> {
        switch event {
        case .delete(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers their version.
            try! self.local.delete(path: path)
            return Future(value: path)
        case .write(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers their version.
            return self.readRemoteAndWrite(path: path).map({ (_) -> Path in
                return path
            })
        }
    }
    
    func readRemoteAndWrite(path: Path) -> Future<File<Data>, RemoteError> {
        return Retry(maxAttempts: 3) {
            return self.remote.read(path: path).onSuccess(callback: { (file: File<Data>) in
                guard let localFile: File<Data> = try? self.local.read(path: path) else {
                    try! self.local.write(file: file)
                    return
                }
                if file.contents != localFile.contents {
                    try! self.local.write(file: file)
                }
            })
            
        }.start().future
    }
    
    func sweep() {
        for path in self.dirtyStore.all() {
            if self.local.exists(path: path) {
                do {
                    let _: File<Data> = try self.local.read(path: path)
                    self.push(event: .write(path: path)).onSuccess(callback: { (_) in
                        self.dirtyStore.remove(path: path)
                    })
                } catch {
                    
                }
            } else {
                self.push(event: .delete(path: path)).onSuccess(callback: { (_) in
                    self.dirtyStore.remove(path: path)
                })
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
