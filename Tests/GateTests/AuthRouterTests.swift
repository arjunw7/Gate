import XCTest
@testable import Gate

final class AuthRouterTests: XCTestCase {

    func testRouteAuthTokenReturns200WithToken() async throws {
        let router = AuthRouter(getToken: { "tok_abc" })
        let result = await router.handle(method: "GET", path: "/auth/token", body: Data())
        XCTAssertEqual(result.statusCode, 200)
        let decoded = try JSONDecoder().decode([String: String].self, from: result.body)
        XCTAssertEqual(decoded["token"], "tok_abc")
    }

    func testRouteAuthTokenReturns401OnLoginCancelled() async throws {
        let router = AuthRouter(getToken: { throw AuthError.loginCancelled })
        let result = await router.handle(method: "GET", path: "/auth/token", body: Data())
        XCTAssertEqual(result.statusCode, 401)
    }

    func testRouteAuthTokenReturns202OnLoginInProgress() async throws {
        let router = AuthRouter(getToken: { throw AuthError.loginInProgress })
        let result = await router.handle(method: "GET", path: "/auth/token", body: Data())
        XCTAssertEqual(result.statusCode, 202)
    }

    func testRouteAuthTokenReturns500OnNetworkError() async throws {
        let router = AuthRouter(getToken: { throw AuthError.networkError("timeout") })
        let result = await router.handle(method: "GET", path: "/auth/token", body: Data())
        XCTAssertEqual(result.statusCode, 500)
    }

    func testRouteAuthTokenReturns500OnKeychainError() async throws {
        let router = AuthRouter(getToken: { throw AuthError.keychainError(errSecItemNotFound) })
        let result = await router.handle(method: "GET", path: "/auth/token", body: Data())
        XCTAssertEqual(result.statusCode, 500)
    }

    func testUnknownPathReturns404() async throws {
        let router = AuthRouter(getToken: { "tok" })
        let result = await router.handle(method: "GET", path: "/unknown", body: Data())
        XCTAssertEqual(result.statusCode, 404)
    }
}
