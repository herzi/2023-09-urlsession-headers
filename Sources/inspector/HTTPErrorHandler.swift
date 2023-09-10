//
//  HTTPErrorHandler.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-10.
//

// Mostly copied from: https://github.com/apple/swift-nio/blob/main/Sources/NIOHTTP1/HTTPServerProtocolErrorHandler.swift

import Foundation

import Logging
import NIO
import NIOHTTP1

final class HTTPErrorHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart
    public typealias OutboundIn = HTTPServerResponsePart
    public typealias OutboundOut = HTTPServerResponsePart

    private var hasUnterminatedResponse: Bool = false
    
    let logger = Logger(label: "http-server-protocol-error-handler")

    public init() {}

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        guard error is HTTPParserError else {
            context.fireErrorCaught(error)
            return
        }
        
        logger.error("HTTP protocol error: \(error)")

        // Any HTTPParserError is automatically fatal, and we don't actually need (or want) to
        // provide that error to the client: we just want to tell it that it screwed up and then
        // let the rest of the pipeline shut the door in its face. However, we can only send an
        // HTTP error response if another response hasn't started yet.
        //
        // A side note here: we cannot block or do any delayed work. ByteToMessageDecoder is going
        // to come along and close the channel right after we return from this function.
        if !self.hasUnterminatedResponse {
            let body = #"{"error":400,"reason":"bad request"}"#
            let headers: HTTPHeaders = [
                "Connection": "close",
                "Content-Length": "\(body.utf8.count)",
                "Content-Type": "application/json; charset=utf-8",
            ]
            let head = HTTPResponseHead(version: .http1_1, status: .badRequest, headers: headers)
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(ByteBuffer(bytes: body.utf8)))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }

        // Now pass the error on in case someone else wants to see it.
        context.fireErrorCaught(error)
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let res = self.unwrapOutboundIn(data)
        switch res {
        case .head:
            precondition(!self.hasUnterminatedResponse)
            self.hasUnterminatedResponse = true
        case .body:
            precondition(self.hasUnterminatedResponse)
        case .end:
            precondition(self.hasUnterminatedResponse)
            self.hasUnterminatedResponse = false
        }
        context.write(data, promise: promise)
    }
}
