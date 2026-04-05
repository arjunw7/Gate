import XCTest
@testable import Gate

final class PermissionStoreTests: XCTestCase {

    var store: PermissionStore!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GateTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = PermissionStore(configDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultModeIsSmartScope() {
        XCTAssertEqual(store.mode, .smartScope)
    }

    func testInMemoryAllowNotPresentInitially() {
        XCTAssertFalse(store.isSessionAllowed(.shell))
    }

    func testSetSessionAllow() {
        store.setSessionAllowed(.shell)
        XCTAssertTrue(store.isSessionAllowed(.shell))
    }

    func testSessionAllowDoesNotPersist() throws {
        store.setSessionAllowed(.fileWrite)
        let freshStore = PermissionStore(configDir: tempDir)
        XCTAssertFalse(freshStore.isPermanentlyAllowed(.fileWrite))
    }

    func testSetPermanentAllow() throws {
        try store.setPermanentlyAllowed(.fileWrite)
        XCTAssertTrue(store.isPermanentlyAllowed(.fileWrite))
    }

    func testPermanentAllowPersistsAcrossInstances() throws {
        try store.setPermanentlyAllowed(.web)
        let freshStore = PermissionStore(configDir: tempDir)
        XCTAssertTrue(freshStore.isPermanentlyAllowed(.web))
    }

    func testResetClearsPermanentAllows() throws {
        try store.setPermanentlyAllowed(.fileWrite)
        try store.setPermanentlyAllowed(.web)
        try store.resetAllPermanent()
        XCTAssertFalse(store.isPermanentlyAllowed(.fileWrite))
        XCTAssertFalse(store.isPermanentlyAllowed(.web))
    }

    func testModePersists() throws {
        try store.setMode(.permanent)
        let freshStore = PermissionStore(configDir: tempDir)
        XCTAssertEqual(freshStore.mode, .permanent)
    }

    func testShouldAutoApprove_SmartScope_FileRead() {
        store = PermissionStore(configDir: tempDir)
        XCTAssertTrue(store.shouldAutoApprove(category: .fileRead))
    }

    func testShouldNotAutoApprove_SmartScope_Shell() {
        store = PermissionStore(configDir: tempDir)
        XCTAssertFalse(store.shouldAutoApprove(category: .shell))
    }

    func testShouldNotAutoApprove_SessionOnly_FileRead() throws {
        try store.setMode(.sessionOnly)
        XCTAssertFalse(store.shouldAutoApprove(category: .fileRead))
    }
}
