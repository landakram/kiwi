
//
//  DropboxRemote.swift
//  Kiwi
//
//  Created by Mark Hudnall on 5/10/17.
//  Copyright © 2017 Mark Hudnall. All rights reserved.
//

import SwiftyDropbox
import RxSwift
import RxSwiftExt

enum RemoteError: Error {
    case WriteError(path: Path)
    case ReadError(path: Path)
}

struct Changeset {
    let entries: Array<Files.Metadata>
    let cursor: String
    
    func merge(other: Changeset) -> Changeset {
        return Changeset(entries: self.entries + other.entries, cursor: other.cursor)
    }
}

struct DropboxError: Error, CustomStringConvertible {
    let description: String
}

class DropboxRemote {
    static let sharedInstance = DropboxRemote()
    
    let root = Path("/")
    var client: DropboxClient?
    
    let localStorage: UserDefaults = UserDefaults.standard
    
    public let forcePollCommand: ReplaySubject<Int> = ReplaySubject.createUnbounded()
    
    var changesets: ConnectableObservable<Changeset>!
    var observable: Observable<FilesystemEvent>!
    
    init(client: DropboxClient? = nil) {
        self.client = client
        
        let scheduler = SerialDispatchQueueScheduler(qos: .default)
        
        let pollLoop = Observable.merge([Observable<Int>.interval(5, scheduler: scheduler), forcePollCommand]).startWith(0)
            .flatMapFirst { (counter) -> Observable<Changeset> in
            return self.longpollAndPull().do(onNext: { (changeset: Changeset) in
                self.localStorage.set(changeset.cursor, forKey: "DropboxCursor")
            }).ignoreErrors()
        }
        
        let cursor: String? = self.localStorage.string(forKey: "DropboxCursor")
        
        var changes: Observable<Changeset>
        
        if cursor == nil {
            changes = self.pullAll().do(onNext: { (c: Changeset) in
                self.localStorage.set(c.cursor, forKey: "DropboxCursor")
            }).concat(pollLoop)
        } else {
            changes = pollLoop.startWith(Changeset(entries: [], cursor: cursor!))
        }
        
        self.changesets = changes.publish()
        
        // Dropbox works with Changesets, but we just want a stream of
        // individual change events. We split changesets into individual
        // events and publish them onto the stream.
        self.observable =
            self.changesets
            .flatMap({ Observable.from($0.entries) })
            .map { (metadata: Files.Metadata) -> FilesystemEvent? in
            let path = Path(metadata.pathDisplay!)
            switch metadata {
            case _ as Files.DeletedMetadata:
                return .delete(path: path)
            case _ as Files.FileMetadata:
                return .write(path: path)
            default:
                return nil
            }
        }.unwrap()
    }
    
    private func longpollAndPull() -> Observable<Changeset> {
        return longpoll().flatMap { (cursor: String) -> Observable<Changeset> in
            return self.pullChanges(cursor: cursor)
        }

    }
    
    private func longpoll() -> Observable<String> {
        return Observable.create { (observer: AnyObserver<String>) -> Disposable in
            let cursor: String = self.localStorage.string(forKey: "DropboxCursor")!
            print("Longpolling ")
            let request = self.client?.files.listFolderLongpoll(cursor: cursor).response { (result: Files.ListFolderLongpollResult?, error: CallError<(Files.ListFolderLongpollError)>?) in
                print("LongPoll result \(result)")
                if result != nil {
                    if result!.changes {
                        observer.onNext(cursor)
                    }
                    observer.onCompleted()
                } else {
                    observer.onError(DropboxError(description: error!.description))
                }
            }
            
            let cancel = Disposables.create {
                request?.cancel()
            }
            return cancel
        }
    }
    
    
    private func pullAll() -> Observable<Changeset> {
        return self.pullFirstPage(path: "").flatMap { (result: Files.ListFolderResult) -> Observable<Changeset> in
            let changeset: Changeset = Changeset(entries: result.entries, cursor: result.cursor)
            
            if result.hasMore {
                return self.pullChangeset(changeset: changeset)
            } else {
                return Observable.just(changeset)
            }
        }
    }
    
    private func pullFirstPage(path: String) -> Observable<Files.ListFolderResult> {
        return Observable<Files.ListFolderResult>.create { observer in
            let request = self.client?.files.listFolder(path: path, recursive: true).response(completionHandler: { (maybeResult: Files.ListFolderResult?, error: CallError<(Files.ListFolderError)>?) in
                guard let result = maybeResult else {
                    observer.onError(DropboxError(description: error!.description))
                    return
                }
                
                observer.onNext(result)
                observer.onCompleted()
            })
            
            let cancel = Disposables.create {
                request?.cancel()
            }
            return cancel
        }
    }
    
    private func pullChanges(cursor: String) -> Observable<Changeset> {
        let initialChangeset: Changeset = Changeset(entries: Array(), cursor: cursor)
        return self.pullChangeset(changeset: initialChangeset)
    }
    
    private func pullChangeset(changeset: Changeset) -> Observable<Changeset> {
        let cursor = changeset.cursor
        
        return self.pullChangesetPage(cursor: cursor).flatMap({ (result: Files.ListFolderResult) -> Observable<Changeset> in
            print("Pulling resulted in \(result.cursor)")
            let newChanges = changeset.merge(other: Changeset(entries: result.entries, cursor: result.cursor))
            if result.hasMore {
                return self.pullChangeset(changeset: newChanges)
            } else {
                return Observable.just(newChanges)
            }
        })
    }
    
    private func pullChangesetPage(cursor: String) -> Observable<Files.ListFolderResult> {
        return Observable.create({ (observer: AnyObserver<Files.ListFolderResult>) -> Disposable in
            let request = self.client?.files.listFolderContinue(cursor: cursor)
            request?.response(completionHandler: { (maybeResult: Files.ListFolderResult?, error: CallError<(Files.ListFolderContinueError)>?) in
                guard let result = maybeResult else {
                    observer.onError(DropboxError(description: error!.description))
                    return
                }
                
                observer.onNext(result)
                observer.onCompleted()
            })
            
            let cancel = Disposables.create {
                request?.cancel()
            }
            return cancel
        })
    }
    
    private func fromRoot(_ path: Path) -> Path {
        debugPrint(path)
        return self.root + path
    }
    
    func configure(client: DropboxClient) {
        print("Configuring DropboxRemote with \(client)")
        self.client = client

        _ = self.changesets.connect() // Start emitting events
    }
        
    func write(file: File<Data>) -> Observable<Either<Progress, Path>> {
        return Observable.create({ observer in
            let request = self.client?.files.upload(path: self.fromRoot(file.path).rawValue, mode: .overwrite, autorename: false, mute: false, input: file.contents)
            request?.progress({ (p: Progress) in
                observer.onNext(.left(p))
            })
            request?.response { (metadata: Files.FileMetadata?, error: CallError<(Files.UploadError)>?) in
                if error == nil {
                    print("write to remote \(file.path.rawValue)")
                    observer.onNext(.right(file.path))
                    observer.onCompleted()
                } else {
                    print("write to remote \(file.path.rawValue) failure: \(error!)")
                    observer.onError(RemoteError.WriteError(path: file.path))
                }
            }
            
            let cancel = Disposables.create {
                request?.cancel()
            }
            return cancel
        })
    }
    
    func delete<T: ReadableWritable>(file: File<T>) -> Observable<Either<Progress, Path>> {
        return self.delete(path: file.path)
    }
    
    func delete(path: Path) -> Observable<Either<Progress, Path>> {
        return Observable.create({ observer in
            let request = self.client?.files.deleteV2(path: self.fromRoot(path).rawValue)
            observer.onNext(.left(Progress(totalUnitCount: 100))) // Fake the progress since Dropbox does not report it
            request?.response(completionHandler: { (result: Files.DeleteResult?, error: CallError<(Files.DeleteError)>?) in
                if error == nil {
                    observer.onNext(.right(path))
                    observer.onCompleted()
                } else {
                    observer.onError(RemoteError.WriteError(path: path))
                }
            })
            let cancel = Disposables.create {
                request?.cancel()
            }
            return cancel
        })
    }
    
    func read(path: Path) -> Observable<Either<Progress, File<Data>>> {
        return Observable.create { observer in
            let request = self.client?.files.download(path: self.fromRoot(path).rawValue)
            request?.progress({ (p: Progress) in
                observer.onNext(.left(p))
            })
            request?.response(completionHandler: { (file: (Files.FileMetadata, Data)?, error: CallError<(Files.DownloadError)>?) in
                if error != nil {
                    observer.onError(RemoteError.ReadError(path: path))
                } else {
                    let f = File<Data>(path: path, modifiedDate: file!.0.serverModified,  contents: file!.1)
                    observer.onNext(.right(f))
                    observer.onCompleted()
                }
            })
            
            let cancel = Disposables.create {
                request?.cancel()
            }
            return cancel
        }
    }
}
