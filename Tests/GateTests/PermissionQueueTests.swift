import XCTest
@testable import Gate

final class PermissionQueueTests: XCTestCase {

    func testSingleRequestCompletesImmediately() {
        let queue = PermissionQueue()
        let expectation = XCTestExpectation(description: "request handled")

        queue.enqueue(sessionId: "s1", showOverlay: { _, respond in
            respond(.allow())
        }, completion: { response in
            XCTAssertEqual(response.hookSpecificOutput.decision.behavior, "allow")
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testSecondRequestWaitsForFirst() {
        let queue = PermissionQueue()
        var order: [String] = []
        let exp1 = XCTestExpectation(description: "first handled")
        let exp2 = XCTestExpectation(description: "second handled")

        queue.enqueue(sessionId: "s1", showOverlay: { _, respond in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                order.append("first")
                respond(.allow())
                exp1.fulfill()
            }
        }, completion: { _ in })

        queue.enqueue(sessionId: "s2", showOverlay: { _, respond in
            order.append("second")
            respond(.deny())
            exp2.fulfill()
        }, completion: { _ in })

        wait(for: [exp1, exp2], timeout: 3.0)
        XCTAssertEqual(order, ["first", "second"])
    }
}
