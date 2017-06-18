//
//  SyncEngine.swift
//  Kiwi
//
//  Created by Mark Hudnall on 11/7/16.
//  Copyright © 2016 Mark Hudnall. All rights reserved.
//

import Foundation
import FileKit
import SwiftyDropbox
import RxSwift

enum Either<T, U> {
    case left(_ : T)
    case right(_ : U)
    
    func isRight() -> Bool {
        switch self {
        case .left(let t):
            return false
        case .right(let u):
            return true
        }
    }
    
    func mapLeft<X>(_ f: (T) -> X) -> Either<X, U> {
        switch self {
        case .left(let t):
            return .left(f(t))
        case .right(let u):
            return .right(u)
        }
    }
    
    func mapRight<Y>(_ f: (U) -> Y) -> Either<T, Y> {
        switch self {
        case .left(let t):
            return .left(t)
        case .right(let u):
            return .right(f(u))
        }
    }
}

enum Operations {
    case PushOperation(operation: PushOperation)
    case PullOperation(operation: PullOperation)
}

protocol Operation {
    associatedtype Result
    var stream: Observable<Either<Progress, Result>> { get }
    func execute() -> Observable<Either<Progress, Result>>
}

class SyncEngine {
    static let sharedInstance = SyncEngine()
    
    let local: Filesystem
    let remote: DropboxRemote
    var dirtyStore: DirtyStore = DirtyStore()
    
    let disposeBag: DisposeBag = DisposeBag()
    
    var events: Observable<Operations> {
        get {
            return self.subject
        }
    }
    var subject: ReplaySubject<Operations> = ReplaySubject.createUnbounded()
    
    init(local: Filesystem = Filesystem.sharedInstance, remote: DropboxRemote = DropboxRemote.sharedInstance) {
        self.local = local
        self.remote = remote
        self.start()
    }
    
    func start() {
        self.local.events.subscribe(onNext: { (event: FilesystemEvent) in
            _ = self.push(event: event)
        }).disposed(by: disposeBag)
        
        self.remote.observable.subscribe(onNext: { (event: FilesystemEvent) in
            _ = self.pull(event: event)
        }).disposed(by: disposeBag)
    }
    
    func push(event: FilesystemEvent) -> Observable<Either<Progress, Path>> {
        let operation = PushOperation(event: event, local: self.local, remote: self.remote, dirtyStore: self.dirtyStore)
        self.subject.onNext(.PushOperation(operation: operation))
        return operation.execute()
    }
    
    func pull(event: FilesystemEvent) -> Observable<Either<Progress, Path>> {
        let operation = PullOperation(event: event, local: self.local, remote: self.remote)
        self.subject.onNext(.PullOperation(operation: operation))
        return operation.execute()
    }

    
    func sweep() {
        for path in self.dirtyStore.all() {
            if self.local.exists(path: path) {
                do {
                    let _: File<Data> = try self.local.read(path: path)
                    self.push(event: .write(path: path)).subscribe(onNext: { (_) in
                        self.dirtyStore.remove(path: path)
                    }).disposed(by: self.disposeBag)
                } catch {
                    
                }
            } else {
                self.push(event: .delete(path: path)).subscribe(onNext: { (_) in
                    self.dirtyStore.remove(path: path)
                }).disposed(by: self.disposeBag)
            }
        }
    }
}

/**
 * Tracks the dirty state of paths in the local filesystem.
 */
struct DirtyStore {
    private var backingSet: Set<String> = Set<String>()
    
    private var localStorage: UserDefaults = UserDefaults.standard
    
    init() {
        if let data = self.localStorage.data(forKey: "DirtyStore") {
            if let storedSet = NSKeyedUnarchiver.unarchiveObject(with: data) as? Set<String> {
                self.backingSet = storedSet
            }
        }
    }
    
    mutating func add(path: Path) {
        backingSet.insert(path.standardRawValue)
        localStorage.set(NSKeyedArchiver.archivedData(withRootObject: backingSet), forKey: "DirtyStore")
    }
    
    mutating func remove(path: Path) {
        backingSet.remove(path.standardRawValue)
        localStorage.set(NSKeyedArchiver.archivedData(withRootObject: backingSet), forKey: "DirtyStore")
    }
    
    func has(path: Path) -> Bool {
        return backingSet.contains(path.standardRawValue)
    }
    
    func all() -> [Path] {
        return self.backingSet.sorted(by: { (first: String, second: String) -> Bool in
            return true
        }).map({ (rawPath: String) -> Path in
            return Path(rawPath)
        })
    }
}

class PushOperation: Operation {
    func execute() -> Observable<Either<Progress, Path>> {
        switch event {
        case .delete(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers our version.
            
            self.dirtyStore.add(path: path)
            self.remote.delete(path: path.relativeTo(self.local.root)).do(onNext: { (e: Either<Progress, Path>) in
                _ = e.mapRight({ (p: Path) -> Path in
                    self.dirtyStore.remove(path: path)
                    return p
                })
            }).subscribe(self.subject)
        case .write(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers our version.
            let file: File<Data> = try! self.local.read(path: path)
            // The path may be absolute, so we need to translate to a relative path
            // that is in common with the remote filesystem.
            //
            // i.e. it might be /usr/docs/wiki/page.md
            // where /usr/docs/ is specific to this platform.
            
            self.dirtyStore.add(path: path)
            self.remote.write(file: File(path: file.path.relativeTo(self.local.root), contents: file.contents)).do(onNext: { (e: Either<Progress, Path>) in
                _ = e.mapRight({ (p: Path) -> Path in
                    self.dirtyStore.remove(path: path)
                    return p
                })
            }).subscribe(self.subject)
        }
        return self.stream
    }
    
    let event: FilesystemEvent
    let local: Filesystem
    let remote: DropboxRemote
    var dirtyStore: DirtyStore
    
    var stream: Observable<Either<Progress, Path>> {
        get {
            return self.subject
        }
    }
    private var subject: ReplaySubject<Either<Progress, Path>> = ReplaySubject.createUnbounded()
    
    init(event: FilesystemEvent, local: Filesystem, remote: DropboxRemote, dirtyStore: DirtyStore) {
        self.event = event
        self.local = local
        self.remote = remote
        self.dirtyStore = dirtyStore
    }
}

class PullOperation: Operation {
    func execute() -> Observable<Either<Progress, Path>> {
        switch event {
        case .delete(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers their version.
            try! self.local.delete(path: path)
            self.subject.onNext(.right(path))
            return self.stream
        case .write(let path):
            // TODO: handle conflicts.
            // Right now, this always prefers their version.
            self.readRemoteAndWrite(path: path).map({ (e: Either<Progress, File<Data>>) in
                return e.mapRight { _ in path }
            }).retry(.exponentialDelayed(maxCount: 3, initial: 1.0, multiplier: 1.0))
                .subscribe(self.subject)
            return self.stream
        }
    }

    let event: FilesystemEvent
    let local: Filesystem
    let remote: DropboxRemote
    
    var stream: Observable<Either<Progress, Path>> {
        get {
            return self.subject
        }
    }
    private var subject: ReplaySubject<Either<Progress, Path>> = ReplaySubject.createUnbounded()
    
    init(event: FilesystemEvent, local: Filesystem, remote: DropboxRemote) {
        self.event = event
        self.local = local
        self.remote = remote
    }
    
    func readRemoteAndWrite(path: Path) -> Observable<Either<Progress, File<Data>>> {
        return self.remote.read(path: path).map({ (e: Either<Progress, File<Data>>) in
            return e.mapRight({ (file: File<Data>) -> File<Data> in
                guard let localFile: File<Data> = try? self.local.read(path: path) else {
                    try! self.local.write(file: file)
                    return file
                }
                if file.contents != localFile.contents {
                    try! self.local.write(file: file)
                }
                return file
            })
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
