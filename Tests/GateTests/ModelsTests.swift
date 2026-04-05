import XCTest
@testable import Gate

final class ModelsTests: XCTestCase {
    func testBashIsShellCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "Bash"), .shell)
    }

    func testEditIsFileWriteCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "Edit"), .fileWrite)
    }

    func testWriteIsFileWriteCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "Write"), .fileWrite)
    }

    func testReadIsFileReadCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "Read"), .fileRead)
    }

    func testGlobIsFileReadCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "Glob"), .fileRead)
    }

    func testGrepIsFileReadCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "Grep"), .fileRead)
    }

    func testWebFetchIsWebCategory() {
        XCTAssertEqual(ToolCategory.from(toolName: "WebFetch"), .web)
    }

    func testUnknownToolIsShellCategory() {
        // Unknown tools default to high-risk shell category
        XCTAssertEqual(ToolCategory.from(toolName: "SomethingNew"), .shell)
    }

    func testShellRiskIsHigh() {
        XCTAssertEqual(ToolCategory.shell.riskLevel, .high)
    }

    func testFileWriteRiskIsMedium() {
        XCTAssertEqual(ToolCategory.fileWrite.riskLevel, .medium)
    }

    func testFileReadRiskIsLow() {
        XCTAssertEqual(ToolCategory.fileRead.riskLevel, .low)
    }
}
