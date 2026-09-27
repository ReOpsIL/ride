import XCTest

final class NoticeQueueTests: XCTestCase {
    func testActionableNoticeIsNotReplacedByAnotherActionableOne() {
        var queue = NoticeQueue()
        XCTAssertNil(queue.push(notice("crash", onDismiss: {})))
        XCTAssertNil(queue.push(notice("tools", action: true)))
        XCTAssertEqual(queue.current?.text, "crash")
        XCTAssertEqual(queue.advance()?.text, "tools")
        XCTAssertNil(queue.advance())
    }

    func testTransientNoticePreemptsAndThenResumesTheActionableOne() {
        var queue = NoticeQueue()
        _ = queue.push(notice("crash", onDismiss: {}))
        XCTAssertNil(queue.push(notice("copied")))
        XCTAssertEqual(queue.current?.text, "copied")
        XCTAssertEqual(queue.advance()?.text, "crash")
    }

    func testTransientNoticeReplacesTransientAndHandsItBack() {
        var queue = NoticeQueue()
        _ = queue.push(notice("one"))
        let replaced = queue.push(notice("two"))
        XCTAssertEqual(replaced?.text, "one")
        XCTAssertEqual(queue.current?.text, "two")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDismissHandlerSurvivesAQueuedNotice() {
        var queue = NoticeQueue()
        var acknowledged = false
        _ = queue.push(notice("crash", onDismiss: { acknowledged = true }))
        _ = queue.push(notice("tools", action: true))
        queue.current?.onDismiss?()
        XCTAssertTrue(acknowledged)
    }

    private func notice(_ text: String, action: Bool = false, onDismiss: (() -> Void)? = nil) -> Notice {
        Notice(text: text, seconds: 1, action: action ? ("Go", {}) : nil, onDismiss: onDismiss)
    }
}
