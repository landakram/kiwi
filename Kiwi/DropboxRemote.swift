//
//  DropboxRemote.swift
//  Kiwi
//
//  Created by Mark Hudnall on 5/10/17.
//  Copyright © 2017 Mark Hudnall. All rights reserved.
//

import SwiftyDropbox
import EmitterKit
import BrightFutures
import FileKit
import Result

enum RemoteError: Error {
    case WriteError(path: Path)
    case ReadError(path: Path)
}

enum DropboxError: Error {
    case ListFolderError(error: CallError<Files.ListFolderError>)
    case ListFolderLongpollError(error: CallError<Files.ListFolderLongpollError>)
    case ListFolderContinueError(error: CallError<Files.ListFolderContinueError>)
}

struct Changeset {
    let entries: Array<Files.Metadata>
    let cursor: String
    
    func merge(other: Changeset) -> Changeset {
        return Changeset(entries: self.entries + other.entries, cursor: other.cursor)
    }
}

class DropboxRemote {
    static let sharedInstance = DropboxRemote()
    let event: Event<FilesystemEvent> = Event()
    let bufferredEvents: Event<Array<FilesystemEvent>> = Event()
    
    let root = Path("/")
    var client: DropboxClient!
    
    let localStorage: UserDefaults = UserDefaults.standard
    
    init(client: DropboxClient? = nil) {
        self.client = client
    }
    
    private func fromRoot(_ path: Path) -> Path {
        return self.root + path
    }
    
    func configure(client: DropboxClient) {
        self.client = client
    }
    
    func start() -> Future<Void, DropboxError> {
        let cursor: String? = self.localStorage.string(forKey: "DropboxCursor")
        var initialSync: Future<Void, DropboxError>
        if cursor == nil {
            initialSync = doInitialSync()
        } else {
            initialSync = Future(result: .success())
        }
        
        initialSync.onSuccess { () in
            self.startGradualSync()
        }
        
        // TODO: handle error above?
        
        return initialSync
    }
    
    private func startGradualSync() {
        DispatchQueue.global().async(execute: syncTask)
    }
    
    private func syncTask() {
        // Start long polling with cursor stored in local storage
        let cursor: String = self.localStorage.string(forKey: "DropboxCursor")!
        self.awaitChanges(cursor: cursor).flatMap { (changes: Bool) -> Future<Changeset, DropboxError>  in
            if changes {
                return self.pullChanges(cursor: cursor)
            } else {
                return Future(value: Changeset(entries: Array(), cursor: cursor))
            }
            }.onSuccess(callback: reconcileChanges).andThen { (result: Result<Changeset, DropboxError>) in
                // Continue long polling
                DispatchQueue.global().async(execute: self.syncTask)
        }
    }
    
    private func reconcileChanges(changeset: Changeset) {
        // When results are received, emit the events
        self.emitFilesystemEvents(entries: changeset.entries)
        
        // Save the new cursor
        self.localStorage.set(changeset.cursor, forKey: "DropboxCursor")
    }
    
    private func emitFilesystemEvents(entries: Array<Files.Metadata>) {
        let events: Array<FilesystemEvent> = entries.flatMap({ (metadata: Files.Metadata) in
            let path = Path(metadata.pathDisplay!)
            switch metadata {
            case _ as Files.DeletedMetadata:
                return .delete(path: path)
            case _ as Files.FileMetadata:
                return .write(path: path)
            default:
                return nil
            }
        })
        
        self.bufferredEvents.emit(events)
        events.forEach { (event) in
            self.event.emit(event)
        }
    }
    
    private func doInitialSync() -> Future<Void, DropboxError> {
        return self.pullAll().onSuccess(callback: reconcileChanges).map { (_) -> Void in
            
        }
    }
    
    private func pullAll() -> Future<Changeset, DropboxError> {
        return self.pullFirstPage(path: "").flatMap { (result: Files.ListFolderResult) -> Future<Changeset, DropboxError> in
            let changeset: Changeset = Changeset(entries: result.entries, cursor: result.cursor)
            
            if result.hasMore {
                return self.pullChangeset(changeset: changeset)
            } else {
                return Future(value: changeset)
            }
        }
    }
    
    private func pullFirstPage(path: String) -> Future<Files.ListFolderResult, DropboxError> {
        return Future<Files.ListFolderResult, DropboxError> { complete in
            self.client.files.listFolder(path: path, recursive: true).response(completionHandler: { (maybeResult: Files.ListFolderResult?, error: CallError<(Files.ListFolderError)>?) in
                guard let result = maybeResult else {
                    complete(.failure(DropboxError.ListFolderError(error: error!)))
                    return
                }
                
                complete(.success(result))
            })
        }
    }
    
    private func pullChanges(cursor: String) -> Future<Changeset, DropboxError> {
        let initialChangeset: Changeset = Changeset(entries: Array(), cursor: cursor)
        return self.pullChangeset(changeset: initialChangeset)
    }
    
    private func pullChangeset(changeset: Changeset) -> Future<Changeset, DropboxError> {
        let cursor = changeset.cursor
        return self.pullChangesetPage(cursor: cursor).flatMap { (result: Files.ListFolderResult) -> Future<Changeset, DropboxError> in
            let newChanges = changeset.merge(other: Changeset(entries: result.entries, cursor: result.cursor))
            if result.hasMore {
                return self.pullChangeset(changeset: newChanges)
            } else {
                return Future(value: newChanges)
            }
        }
    }
    
    private func pullChangesetPage(cursor: String) -> Future<Files.ListFolderResult, DropboxError> {
        return Future<Files.ListFolderResult, DropboxError> { complete in
            self.client.files.listFolderContinue(cursor: cursor).response(completionHandler: { (maybeResult: Files.ListFolderResult?, error: CallError<(Files.ListFolderContinueError)>?) in
                guard let result = maybeResult else {
                    complete(.failure(DropboxError.ListFolderContinueError(error: error!)))
                    return
                }
                
                complete(.success(result))
            })
        }
    }
    
    private func awaitChanges(cursor: String) -> Future<Bool, DropboxError> {
        return Future<Bool, DropboxError> { complete in
            self.client.files.listFolderLongpoll(cursor: cursor).response { (result: Files.ListFolderLongpollResult?, error: CallError<(Files.ListFolderLongpollError)>?) in
                if result != nil {
                    complete(.success(result!.changes))
                } else {
                    complete(.failure(DropboxError.ListFolderLongpollError(error: error!)))
                }
            }
        }
    }
    
    func write(file: File<Data>) -> Future<Path, RemoteError> {
        let request = self.client.files.upload(path: fromRoot(file.path).rawValue, mode: .overwrite, autorename: false, mute: false, input: file.contents)
        return Future<Path, RemoteError> { complete in
            request.response { (metadata: Files.FileMetadata?, error: CallError<(Files.UploadError)>?) in
                if error == nil {
                    print("remote write \(file.path.rawValue)")
                    complete(.success(file.path))
                } else {
                    print("remote write \(file.path.rawValue) failure: \(error!)")
                    
                    complete(.failure(RemoteError.WriteError(path: file.path)))
                }
            }
        }
    }
    
    func delete<T: ReadableWritable>(file: File<T>) -> Future<Path, RemoteError> {
        return self.delete(path: file.path)
    }
    
    func delete(path: Path) -> Future<Path, RemoteError> {
        let request = self.client.files.delete(path: fromRoot(path).rawValue)
        return Future<Path, RemoteError> { complete in
            request.response(completionHandler: { (metadata: Files.Metadata?, error: CallError<(Files.DeleteError)>?) in
                if error == nil {
                    complete(.success(path))
                } else {
                    complete(.failure(RemoteError.WriteError(path: path)))
                }
            })
        }
    }
    
    func read(path: Path) -> Future<File<Data>, RemoteError> {
        return Future<File<Data>, RemoteError> { complete in
            let request = self.client.files.download(path: fromRoot(path).rawValue)
            request.progress({ (p: Progress) in
                
            })
            request.response(completionHandler: { (file: (Files.FileMetadata, Data)?, error: CallError<(Files.DownloadError)>?) in
                if error != nil {
                    complete(.failure(RemoteError.ReadError(path: path)))
                } else {
                    let f = File<Data>(path: path, modifiedDate: file!.0.serverModified,  contents: file!.1)
                    complete(.success(f))
                }
            })
        }
    }
}
