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
            var filesystem: FakeFilesystem!
            var page1: Page!
            var page2: Page!

            func toDate(str: String) -> Date {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy'-'MM'-'dd"
                return dateFormatter.date(from: str)!
            }
            
            beforeEach {
                filesystem = FakeFilesystem()
                indexer = Indexer(filesystem: filesystem)
                indexer.start()
                page1 = Page(
                    rawContent: "test",
                    permalink: "test_page",
                    name: "Test",
                    modifiedTime: toDate(str: "2019-11-01"),
                    createdTime: toDate(str: "2019-11-01"),
                    isDirty: false
                )
                page2 = Page(
                    rawContent: "test2",
                    permalink: "test_page2",
                    name: "Test2",
                    modifiedTime: toDate(str: "2019-11-02"),
                    createdTime: toDate(str: "2019-11-02"),
                    isDirty: false
                )
            }
            
            afterEach {
                indexer.removeAll()
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
                    indexer.index(page: page1)
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

            describe(".list") {
                beforeEach {
                    indexer.list().map { (permalink) in
                        indexer.remove(permalink: permalink)
                    }
                    indexer.index(page: page1)
                    indexer.index(page: page2)
                }

                it("returns all permalinks in descending order") {
                    let permalinks = indexer.list()
                    expect(permalinks).to(equal([page2.permalink, page1.permalink]))
                }
            }
        }
    }
}
