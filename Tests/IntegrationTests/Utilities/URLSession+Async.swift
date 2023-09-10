//
//  URLSession+Async.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-09.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if os(Linux)
extension URLSession {
    func data (for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                guard let response else {
                    return continuation.resume(throwing: error ?? URLError(.unknown))
                }
                continuation.resume(returning: (data ?? Data(), response))
            }
            task.resume()
        }
    }
}
#endif
