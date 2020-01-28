//
//  NullRemote.swift
//  Kiwi
//
//  Created by Mark Hudnall on 1/16/20.
//  Copyright © 2020 Mark Hudnall. All rights reserved.
//

import Foundation
import RxSwift
import RxSwiftExt

// This implementation of Remote no-ops on most operations, immediately completing
// the observable.
//
// When asked to read a file, it reads the file from the local filesystem.
class NullRemote: Remote {
    static let sharedInstance = NullRemote()
    
    let filesystem: Filesystem
    let root = Path("/")
    let events: Observable<FilesystemEvent>!
    
    var configured: Bool
    
    init(filesystem: Filesystem = Filesystem.sharedInstance) {
        self.filesystem = filesystem
        self.events = Observable.create({ (observable) -> Disposable in
            return Disposables.create()
        })
        self.configured = true
    }
    
    func configure(configured: Bool) {
        self.configured = configured
    }
    
    func write(file: File<Data>) -> Observable<Either<Progress, Path>> {
        return Observable.create { (observer) -> Disposable in
            observer.onNext(.right(self.fromRoot(file.path)))
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    func delete<T: ReadableWritable>(file: File<T>) -> Observable<Either<Progress, Path>> {
        return Observable.create { (observer) -> Disposable in
            observer.onNext(.right(self.fromRoot(file.path)))
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    func delete(path: Path) -> Observable<Either<Progress, Path>> {
        return Observable.create { (observer) -> Disposable in
            observer.onNext(.right(self.fromRoot(path)))
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    func read(path: Path) -> Observable<Either<Progress, File<Data>>> {
        return Observable.create { (observer) -> Disposable in
            guard let file: File<Data> = try? self.filesystem.read(path: path) else {
                observer.onError(RemoteError.ReadError(path: path))
                return Disposables.create()
            }
            observer.onNext(.right(file))
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    static func description() -> String {
        return "NullRemote"
    }
    
    private func fromRoot(_ path: Path) -> Path {
        debugPrint(path)
        return self.root + path
    }
}
