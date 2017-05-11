//
//  EventBus.swift
//  Kiwi
//
//  Created by Mark Hudnall on 5/7/17.
//  Copyright © 2017 Mark Hudnall. All rights reserved.
//

import Foundation
import EmitterKit
import SwiftyDropbox

class EventBus {
    static let sharedInstance = EventBus()
    let accountLinkEvents: Event<AccountLinkEvent> = Event()
}

enum AccountLinkEvent {
    case AccountLinked(authResult: DropboxOAuthResult)
}
