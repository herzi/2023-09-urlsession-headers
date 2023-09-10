# URLSession Headers when Using `httpBodyStream`

## Problem Statement

When porting some macOS code to Linux, I observed unexpected behavior in a backend call involving
`URLRequest.httpBodyStream`.

## Reproduce

In order to reproduce this, the author assumes you have a working setup of docker on macOS.

### Step 1: Build Docker Image

```
$ docker-compose build
```

### Step 2: Start Docker Images and Observe Failing Linux Test

```
$ docker compose run testing
[…]
Test Case 'URLSessionTests.testStreamingUpload' started at 2023-09-10 12:06:10.564
/build/Tests/IntegrationTests/URLSessionTests.swift:87: error: URLSessionTests.testStreamingUpload : XCTAssertEqual failed: ("Optional(400)") is not equal to ("Optional(200)") - 
/build/Tests/IntegrationTests/URLSessionTests.swift:88: error: URLSessionTests.testStreamingUpload : XCTAssertEqual failed: ("Optional("application/json; charset=utf-8")") is not equal to ("Optional("application/json")") - "<HTTPURLResponse 0x00007fe3f000fe60> { URL: http://inspector:8080/headers }{ status: 400, headers {\n   \"Connection\" = close;\n   \"Content-Length\" = 36;\n   \"Content-Type\" = \"application/json; charset=utf-8\";\n} }"
/build/Tests/IntegrationTests/URLSessionTests.swift:95: error: URLSessionTests.testStreamingUpload : failed - body: {"error":400,"reason":"bad request"}
<EXPR>:0: error: URLSessionTests.testStreamingUpload : threw error "typeMismatch(Swift.Array<Foundation.JSONValue>, Swift.DecodingError.Context(codingPath: [_JSONKey(stringValue: "error", intValue: nil)], debugDescription: "Expected to decode Array<JSONValue> but found a number instead.", underlyingError: nil))"
Test Case 'URLSessionTests.testStreamingUpload' failed (0.247 seconds)
Test Suite 'URLSessionTests' failed at 2023-09-10 12:06:10.811
     Executed 1 test, with 4 failures (1 unexpected) in 0.247 (0.247) seconds
Test Suite 'testing.xctest' failed at 2023-09-10 12:06:10.811
     Executed 1 test, with 4 failures (1 unexpected) in 0.247 (0.247) seconds
Test Suite 'All tests' failed at 2023-09-10 12:06:10.811
     Executed 1 test, with 4 failures (1 unexpected) in 0.247 (0.247) seconds
```

### Step 3: Start Service and Observe Succeeding Test on macOS

```
$ docker compose start inspector && swift test || docker compose logs inspector; docker compose stop inspector
[+] Running 1/1
 ✔ Container 2023-09-urlsession-headers-inspector-1  Started                                                                                                                                                                                                                          0.2s 
Building for debugging...
Build complete! (0.37s)
Test Suite 'All tests' started at 2023-09-10 14:08:35.395
Test Suite '2023-09-urlsession-headersPackageTests.xctest' started at 2023-09-10 14:08:35.396
Test Suite 'URLSessionTests' started at 2023-09-10 14:08:35.397
Test Case '-[IntegrationTests.URLSessionTests testStreamingUpload]' started.
Test Case '-[IntegrationTests.URLSessionTests testStreamingUpload]' passed (0.041 seconds).
Test Suite 'URLSessionTests' passed at 2023-09-10 14:08:35.438.
     Executed 1 test, with 0 failures (0 unexpected) in 0.041 (0.042) seconds
Test Suite '2023-09-urlsession-headersPackageTests.xctest' passed at 2023-09-10 14:08:35.438.
     Executed 1 test, with 0 failures (0 unexpected) in 0.041 (0.042) seconds
Test Suite 'All tests' passed at 2023-09-10 14:08:35.438.
     Executed 1 test, with 0 failures (0 unexpected) in 0.041 (0.043) seconds
[+] Stopping 1/1
 ✔ Container 2023-09-urlsession-headers-inspector-1  Stopped                                                                                                                                                                                                                          0.1s 
```

## Credits

* **Helge Hess** for [A µTutorial on SwiftNIO 2](https://www.alwaysrightinstitute.com/microexpress-nio2/), serving as the foundation for the `inspector` tool.
* **Harrison Harnisch** for [Integration Testing With Docker Compose](https://blog.harrison.dev/2016/06/19/integration-testing-with-docker-compose.html).
