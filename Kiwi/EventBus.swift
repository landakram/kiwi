//
//  EventBus.swift
//  Kiwi
//
//  Created by Mark Hudnall on 5/7/17.
//  Copyright © 2017 Mark Hudnall. All rights reserved.
//

import Foundation
import RxSwift
import SwiftyDropbox

class EventBus {
    static let sharedInstance = EventBus()
    
    var accountLinkEvents: Observable<AccountLinkEvent> {
        get {
            return accountLinkEventsSubject.asObservable()
        }
    }
    private let accountLinkEventsSubject: PublishSubject<AccountLinkEvent> = PublishSubject()
    
    func publish(event: AccountLinkEvent) {
        self.accountLinkEventsSubject.onNext(event)
    }
}

enum AccountLinkEvent {
    case AccountLinked(authResult: DropboxOAuthResult)
}
