import XCTest
@testable import Gate

final class TranscriptReaderTests: XCTestCase {

    func testExtractsLastAssistantText() throws {
        let jsonl = """
        {"role":"user","content":"fix the auth bug"}
        {"role":"assistant","content":"I'll update the token expiry to fix this."}
        {"role":"assistant","content":"Let me also check the session store."}
        """
        let result = TranscriptReader.extractLastAssistantMessage(from: jsonl)
        XCTAssertEqual(result, "Let me also check the session store.")
    }

    func testReturnsNilWhenNoAssistantMessage() {
        let jsonl = """
        {"role":"user","content":"hello"}
        """
        let result = TranscriptReader.extractLastAssistantMessage(from: jsonl)
        XCTAssertNil(result)
    }

    func testReturnsNilOnEmptyString() {
        XCTAssertNil(TranscriptReader.extractLastAssistantMessage(from: ""))
    }

    func testReturnsNilOnMalformedLines() {
        let jsonl = "not valid json\nalso not json"
        XCTAssertNil(TranscriptReader.extractLastAssistantMessage(from: jsonl))
    }

    func testHandlesArrayContentFormat() throws {
        let jsonl = """
        {"role":"assistant","content":[{"type":"text","text":"Pushing the fix to remote."}]}
        """
        let result = TranscriptReader.extractLastAssistantMessage(from: jsonl)
        XCTAssertEqual(result, "Pushing the fix to remote.")
    }

    func testReadFromFile() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).jsonl")
        let jsonl = """
        {"role":"user","content":"run tests"}
        {"role":"assistant","content":"Running the test suite now."}
        """
        try jsonl.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = TranscriptReader.read(from: tempFile.path)
        XCTAssertEqual(result, "Running the test suite now.")
    }

    func testReadFromFileMissingFileReturnsNil() {
        let result = TranscriptReader.read(from: "/nonexistent/path/to/file.jsonl")
        XCTAssertNil(result)
    }
}
