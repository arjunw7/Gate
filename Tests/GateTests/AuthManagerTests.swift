import XCTest
@testable import Gate

final class AuthManagerTests: XCTestCase {

    var manager: AuthManager!

    override func setUp() {
        super.setUp()
        // Use a unique account per test run to avoid cross-test pollution
        manager = AuthManager(keychainAccount: "test-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? manager.deleteStoredToken()
        super.tearDown()
    }

    // MARK: - Keychain round-trip

    func testSaveAndLoadToken() throws {
        let token = StoredToken(
            accessToken: "access_abc",
            refreshToken: "refresh_xyz",
            expiresAt: 9999999999
        )
        try manager.saveToken(token)
        let loaded = try manager.loadToken()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded!.accessToken, "access_abc")
        XCTAssertEqual(loaded!.refreshToken, "refresh_xyz")
        XCTAssertEqual(loaded!.expiresAt, 9999999999)
    }

    func testLoadReturnsNilWhenNoToken() throws {
        let loaded = try manager.loadToken()
        XCTAssertNil(loaded)
    }

    func testUpdateToken() throws {
        let initial = StoredToken(accessToken: "old", refreshToken: "r", expiresAt: 1000)
        try manager.saveToken(initial)
        let updated = StoredToken(accessToken: "new", refreshToken: "r2", expiresAt: 2000)
        try manager.saveToken(updated)
        let loaded = try manager.loadToken()
        XCTAssertEqual(loaded!.accessToken, "new")
        XCTAssertEqual(loaded!.expiresAt, 2000)
    }

    func testDeleteToken() throws {
        let token = StoredToken(accessToken: "a", refreshToken: "r", expiresAt: 1000)
        try manager.saveToken(token)
        try manager.deleteStoredToken()
        let loaded = try manager.loadToken()
        XCTAssertNil(loaded)
    }

    // MARK: - Token freshness

    func testTokenIsFreshWhenExpiresAtIsFarFuture() {
        let token = StoredToken(accessToken: "a", refreshToken: "r", expiresAt: Int(Date().timeIntervalSince1970) + 7200)
        XCTAssertTrue(token.isFresh)
    }

    func testTokenIsNotFreshWhenExpiringSoon() {
        let token = StoredToken(accessToken: "a", refreshToken: "r", expiresAt: Int(Date().timeIntervalSince1970) + 30)
        XCTAssertFalse(token.isFresh)
    }

    func testTokenIsNotFreshWhenExpired() {
        let token = StoredToken(accessToken: "a", refreshToken: "r", expiresAt: Int(Date().timeIntervalSince1970) - 100)
        XCTAssertFalse(token.isFresh)
    }

    // MARK: - getToken: fresh token path

    func testGetTokenReturnsFreshAccessToken() async throws {
        let farFuture = Int(Date().timeIntervalSince1970) + 7200
        let token = StoredToken(accessToken: "fresh_token", refreshToken: "r", expiresAt: farFuture)
        try manager.saveToken(token)
        let result = try await manager.getToken()
        XCTAssertEqual(result, "fresh_token")
    }

    // MARK: - Non-blocking login

    func testGetTokenThrowsLoginInProgressWhenNoStoredToken() async throws {
        do {
            _ = try await manager.getToken()
            XCTFail("Expected loginInProgress")
        } catch AuthError.loginInProgress {
            // expected — getToken fires login in background and returns immediately
        }
    }

    func testGetTokenThrowsLoginInProgressOnSecondCallWhileLoginPending() async throws {
        _ = try? await manager.getToken()
        do {
            _ = try await manager.getToken()
            XCTFail("Expected loginInProgress on second call")
        } catch AuthError.loginInProgress {
            // expected
        }
    }
}
