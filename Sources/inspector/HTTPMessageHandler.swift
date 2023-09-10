//
//  HTTPMessageHandler.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-10.
//

import Foundation

import Logging
import NIO
import NIOHTTP1

class HTTPMessageHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    let logger = Logger(label: "http-handler")
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case let .head(header):
            let request  = IncomingMessage(header: header)
            let response = ServerResponse(channel: context.channel, logger: logger)
            defer { logger.info("Processed: \(request.header.uri)") }
            
            response.headers.add(name: "Content-Type", value: "application/json")
            guard header.uri == "/headers" else {
                response.status = .notFound
                response.send(#"{"error":404,"reason":"not found"}"# + "\n\n")
                return
            }
            
            let headers = header.headers.reduce(into: [String: [String]]()) { partialResult, header in
                guard let existingKey = partialResult.keys
                    .first(where: { $0.caseInsensitiveCompare(header.name) == .orderedSame }),
                      let values = partialResult[existingKey]
                else {
                    partialResult[header.name] = [header.value]
                    return
                }
                partialResult[existingKey] = values + CollectionOfOne(header.value)
            }
            
            let json = try! JSONEncoder().encode(headers)
            response.headers.add(name: "Content-Length", value: String(json.count))
            response.send(ByteBuffer(bytes: json))
        case .body, .end:
            break
        }
    }
}
