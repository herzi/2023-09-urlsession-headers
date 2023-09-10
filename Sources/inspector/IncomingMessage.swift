//
//  IncomingMessage.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-09.
//

import NIOHTTP1

open class IncomingMessage {
    let header: HTTPRequestHead // <= from NIOHTTP1
    var userInfo = [String: Any]()
    
    init(header: HTTPRequestHead) {
        self.header = header
    }
}
