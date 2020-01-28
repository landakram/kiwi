//
//  KiwiUITests.swift
//  KiwiUITests
//
//  Created by Mark Hudnall on 1/16/20.
//  Copyright © 2020 Mark Hudnall. All rights reserved.
//

import XCTest
import Kiwi

class KiwiUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset"]
        setupSnapshot(app)
        app.launch()
//        snapshot("OnboardingScreen")
        app.buttons["Get Started"].tap()
        snapshot("GetStartedScreen")
        app.buttons["Store Locally"].tap()
//        app.staticTexts["Home"].waitForExistence(timeout: 1)
        snapshot("ViewWikiScreen")
        
        app.navigationBars["Home"].buttons["Edit"].tap()
        
        let personalWikiTextView = app.textViews.containing(.link, identifier:"personal wiki").element
        personalWikiTextView.swipeDown()
        snapshot("EditScreen")
        
        app.navigationBars["Add Page"].buttons["checkmark"].tap()
        app.navigationBars["Home"].buttons["Home"].tap()
        snapshot("Search")
        
        app.tables.staticTexts["Writing With Kiwi"].tap()
        app.staticTexts["This is another thing"].firstMatch.tap()
        snapshot("WritingWithKiwi")
    }
}
