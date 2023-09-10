//
//  Inspector.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-09.
//

import Foundation

import Logging
import NIO
import NIOHTTP1
import ServiceLifecycle

final class Inspector {
    
    let logger = Logger(label: "inspector")
    
    let loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    func listen(_ port: Int) async throws {
        let reuseAddrOpt = ChannelOptions.socket(
            SocketOptionLevel(SOL_SOCKET),
            SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: loopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddrOpt, value: 1)
        
            .childChannelInitializer { channel in
                channel.pipeline
                    .configureHTTPServerPipeline(withErrorHandling: false)
                    .flatMap { channel.pipeline.addHandler(HTTPMessageHandler()) }
                    .flatMap { channel.pipeline.addHandler(HTTPErrorHandler()) }
            }
        
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        #if os(macOS)
        let addr = sockaddr_in(
            sin_len: numericCast(MemoryLayout<sockaddr_in>.size),
            sin_family: numericCast(AF_INET),
            sin_port: UInt16(8080).bigEndian,
            sin_addr: .init(s_addr: INADDR_ANY),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
        #elseif os(Linux)
        let addr = sockaddr_in(
            sin_family: numericCast(AF_INET),
            sin_port: UInt16(8080).bigEndian,
            sin_addr: .init(s_addr: INADDR_ANY),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
        #endif
        let serverChannel = try await bootstrap.bind(to: .init(addr)).get()
        logger.notice("Server running on: \(serverChannel.localAddress!)")
        
        try await withGracefulShutdownHandler {
            try await serverChannel.closeFuture.get()
        } onGracefulShutdown: { [logger] in
            do {
                try serverChannel.close().wait()
            } catch {
                logger.error("Error terminating server: \(error)")
                assertionFailure("Error terminating server: \(error)")
            }
        }
    }
}

extension Inspector: Service {
    public func run() async throws {
        try await listen(8080)
    }
}
