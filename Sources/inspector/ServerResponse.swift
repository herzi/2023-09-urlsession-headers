//
//  ServerResponse.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-09.
//

import Logging
import NIO
import NIOHTTP1

open class ServerResponse {
    public var status = HTTPResponseStatus.ok
    public var headers = HTTPHeaders()
    public let channel: Channel
    private var didWriteHeader = false
    private var didEnd = false
    
    private let logger: Logger
    
    public init(channel: Channel, logger: Logger) {
        self.channel = channel
        self.logger = logger
    }
    
    func send (_ bytes: ByteBuffer) {
        flushHeader()
        
        let part = HTTPServerResponsePart.body(.byteBuffer(bytes))
        
        _ = channel.writeAndFlush(part)
            .recover(handleError)
            .map(end)
    }
    
    /// An Express like `send()` function.
    open func send(_ s: String) {
        var buffer = channel.allocator.buffer(capacity: s.count)
        buffer.writeString(s)
        send(buffer)
    }
    
    /// Check whether we already wrote the response header.
    /// If not, do so.
    func flushHeader() {
        guard !didWriteHeader else { return } // done already
        didWriteHeader = true
        
        let head = HTTPResponseHead(version: .init(major:1, minor:1),
                                    status: status, headers: headers)
        let part = HTTPServerResponsePart.head(head)
        _ = channel.writeAndFlush(part).recover(handleError)
    }
    
    func handleError(_ error: Error) {
        logger.error("\(error)")
        end()
    }
    
    func end() {
        guard !didEnd else { return }
        didEnd = true
        _ = channel.writeAndFlush(HTTPServerResponsePart.end(nil))
            .map { self.channel.close() }
    }
}
