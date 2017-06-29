//
//  IndexerSpec.swift
//  Kiwi
//
//  Created by Mark Hudnall on 6/28/17.
//  Copyright © 2017 Mark Hudnall. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import FileKit
@testable import Kiwi

class FakeFilesystem: EventedFilesystem {
    var events: Observable<FilesystemEvent> {
        get {
            return subject.asObservable()
        }
    }
    var subject: PublishSubject<FilesystemEvent> = PublishSubject()
    
    var root: Path = Path("/some/path")
    
    func list(path: Path) -> [Path] {
        return []
    }
    
    func read<T: ReadableWritable>(path: Path) throws -> Kiwi.File<T> {
        return Kiwi.File(path: path, modifiedDate: Date(), contents: "Blah" as! T)
    }
    
    func mkdir(path: Path) throws {
        
    }
    
    func exists(path: Path) -> Bool {
        return true
    }
    
    func write<T: ReadableWritable>(file: Kiwi.File<T>, emit: Bool) throws {
        
    }
    
    func delete<T: ReadableWritable>(file: Kiwi.File<T>, emit: Bool) throws {
        
    }
    
    func delete(path: Path, emit: Bool) throws {
        
    }
    
    func touch(path: Path, modificationDate: Date) throws {
        
    }
}

class IndexerSpec: QuickSpec {
    
    override func spec() {
        describe("the Indexer") {
            var indexer: Indexer!
            var page: Page!
            var filesystem: FakeFilesystem!
            
            beforeEach {
                filesystem = FakeFilesystem()
                indexer = Indexer(filesystem: filesystem)
                indexer.start()
                page = Page(rawContent: "test", permalink: "test_page", name: "Test", modifiedTime: Date(), createdTime: Date(), isDirty: false)
            }
            
            context("when a page is written to the filesystem") {
                beforeEach {
                    filesystem.subject.onNext(.write(path: "/some/path/wiki/test_page.md"))
                }
                
                it("should index the page") {
                    expect(indexer.get(permalink: "test_page")).toEventuallyNot(beNil())
                }
            }
            
            context("when a page is indexed") {
                beforeEach {
                    indexer.index(page: page)
                }
                
                context("when a file is removed from the filesystem") {
                    beforeEach {
                        filesystem.subject.onNext(FilesystemEvent.delete(path: "/some/path/wiki/test_page.md"))
                    }
                    
                    it("should remove it from the index") {
                        expect(indexer.get(permalink: "test_page")).toEventually(beNil())
                    }
                }
            }
        }
    }
}
