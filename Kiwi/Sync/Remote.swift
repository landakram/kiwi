//
//  Remote.swift
//  Kiwi
//
//  Created by Mark Hudnall on 1/16/20.
//  Copyright © 2020 Mark Hudnall. All rights reserved.
//

import Foundation
import RxSwift
import RxSwiftExt

protocol Remote {
    var events: Observable<FilesystemEvent>! { get }
    func write(file: File<Data>) -> Observable<Either<Progress, Path>>
    func delete<T: ReadableWritable>(file: File<T>) -> Observable<Either<Progress, Path>>
    func delete(path: Path) -> Observable<Either<Progress, Path>>
    func read(path: Path) -> Observable<Either<Progress, File<Data>>>
    var configured: Bool { get }
    static func description() -> String
}

enum RemoteError: Error {
    case WriteError(path: Path)
    case ReadError(path: Path)
}
