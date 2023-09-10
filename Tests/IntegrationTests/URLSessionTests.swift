//
//  IntgrationTests.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-09.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import XCTest

final class URLSessionTests: XCTestCase {
    
    // MARK: Clean Up of Temporary Files after Running Tests
    
    private var filesPendingDeletion = [URL]()
    
    override func tearDown() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in filesPendingDeletion {
                group.addTask { try FileManager.default.removeItem(at: file) }
            }
            try await group.waitForAll()
        }
    }
    
    // MARK: Builder Methods
    
    /// Create a temporary file.
    ///
    /// This builder creates a temporary file, registers it for deletion at teadown() and writes some data into it.
    private func createFile () throws -> (location: URL, content: Data) {
        let template = FileManager.default.temporaryDirectory
            .appendingPathComponent(ProcessInfo.processInfo.processName)
            .appendingPathExtension("XXXXXX")
        var buffer = template.withUnsafeFileSystemRepresentation { buffer in
            guard let buffer else { preconditionFailure() }
            return Data(bytes: UnsafeRawPointer(buffer), count: strlen(buffer) + 1)
        }
        let (handle, location) = buffer.withUnsafeMutableBytes { buffer -> (FileHandle, URL) in
            let rebound = buffer.bindMemory(to: CChar.self)
            let fd = mkstemp(rebound.baseAddress!) // Linux requires unwrapping
            if fd < 0 {
                perror("mkdtemp()")
                preconditionFailure()
            }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            guard let base = rebound.baseAddress else { preconditionFailure() }
            let location = URL(fileURLWithFileSystemRepresentation: base, isDirectory: false, relativeTo: nil)
            return (handle, location)
        }
        filesPendingDeletion.append(location)
        let content = Data(location.absoluteString.utf8)
        try handle.write(contentsOf: content)
        return (location, content)
    }
    
    // MARK: Integration Tests
    
    // https://stackoverflow.com/questions/3304126/chunked-encoding-and-content-length-header#3304186
    func testStreamingUpload () async throws {
        // Arrange:
        let (file, content) = try createFile()
        #if os(macOS)
        let location = URL(string: "http://localhost:8080/headers")!
        #else
        let location = URL(string: "http://inspector:8080/headers")!
        #endif
        var request = URLRequest(url: location)
        request.httpMethod = "POST"
        request.setValue(String(content.count), forHTTPHeaderField: "Content-Length")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(url: file)
        let sut = URLSession.shared
        
        // Act:
        let task = Task { [request] in try await sut.data(for: request) }
        let result = await task.result
        
        // Assert:
        XCTAssertNoThrow(try result.get())
        let (data, response) = try result.get()
        let http = response as? HTTPURLResponse
        XCTAssertEqual(http?.statusCode, 200)
        XCTAssertEqual(http?.value(forHTTPHeaderField: "Content-Type"), "application/json",
                       "\(response)".debugDescription)
        do {
            let headers = try JSONDecoder().decode([String: [String]].self, from: data)
            XCTAssertEqual(content.count, headers["Content-Length"].flatMap(\.first).flatMap(Int.init(_:)))
            XCTAssertNil(headers["Transport-Encoding"])
        } catch {
            XCTFail("body: \(String(data: data, encoding: .utf8) ?? data.base64EncodedString())")
            throw error
        }
    }

}
