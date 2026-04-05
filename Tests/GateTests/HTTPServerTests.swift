// Tests/GateTests/HTTPServerTests.swift
import XCTest
@testable import Gate

final class HTTPServerTests: XCTestCase {

    func testServerStartsAndAcceptsConnection() throws {
        let expectation = XCTestExpectation(description: "server responds")
        let server = HTTPServer(port: 29099)

        var receivedPayload: PermissionPayload? = nil
        server.onPermissionRequest = { payload, respond in
            receivedPayload = payload
            respond(.allow())
            expectation.fulfill()
        }
        try server.start()
        defer { server.stop() }

        let payload = """
        {"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test-123","cwd":"/tmp","transcript_path":null}
        """
        var request = URLRequest(url: URL(string: "http://localhost:29099/permission")!)
        request.httpMethod = "POST"
        request.httpBody = payload.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            if let data = data,
               let decoded = try? JSONDecoder().decode(HookResponse.self, from: data) {
                XCTAssertEqual(decoded.hookSpecificOutput.decision.behavior, "allow")
            }
        }.resume()

        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(receivedPayload?.tool_name, "Bash")
        XCTAssertEqual(receivedPayload?.session_id, "test-123")
    }

    func testServerReturnsDenyResponse() throws {
        let expectation = XCTestExpectation(description: "deny response received")
        let server = HTTPServer(port: 29098)

        server.onPermissionRequest = { _, respond in
            respond(.deny())
        }
        try server.start()
        defer { server.stop() }

        var request = URLRequest(url: URL(string: "http://localhost:29098/permission")!)
        request.httpMethod = "POST"
        request.httpBody = """
        {"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.txt"},"session_id":"s1","cwd":"/tmp","transcript_path":null}
        """.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let decoded = try? JSONDecoder().decode(HookResponse.self, from: data) {
                XCTAssertEqual(decoded.hookSpecificOutput.decision.behavior, "deny")
                expectation.fulfill()
            }
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }
}
