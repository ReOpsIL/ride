import XCTest
@testable import Ride

final class NavigationHistoryTests: XCTestCase {
    private let a = UUID()
    private let b = UUID()

    func testBackAndForwardWalkTheRing() {
        let history = NavigationHistory()
        let lines: (Int) -> Int = { $0 / 10 }
        history.record(NavLocation(bufferID: a, utf16: 0), lines: lines)
        history.record(NavLocation(bufferID: a, utf16: 50), lines: lines)
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
        let back = history.back(from: NavLocation(bufferID: b, utf16: 5), lines: lines)
        XCTAssertEqual(back, NavLocation(bufferID: a, utf16: 50))
        XCTAssertTrue(history.canGoForward)
        XCTAssertEqual(history.forward(), NavLocation(bufferID: b, utf16: 5))
        XCTAssertNil(history.forward())
    }

    func testSameLineReplacesInsteadOfAppending() {
        let history = NavigationHistory()
        let lines: (Int) -> Int = { $0 / 10 }
        history.record(NavLocation(bufferID: a, utf16: 12), lines: lines)
        history.record(NavLocation(bufferID: a, utf16: 15), lines: lines)
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.utf16, 15)
    }

    func testNewRecordDropsForwardEntriesAndForgetRemovesBuffer() {
        let history = NavigationHistory()
        let lines: (Int) -> Int = { $0 }
        history.record(NavLocation(bufferID: a, utf16: 1), lines: lines)
        history.record(NavLocation(bufferID: b, utf16: 2), lines: lines)
        _ = history.back(from: NavLocation(bufferID: b, utf16: 2), lines: lines)
        history.record(NavLocation(bufferID: a, utf16: 9), lines: lines)
        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.entries.map(\.utf16), [1, 9])
        history.forget(bufferID: a)
        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertFalse(history.canGoBack)
    }
}
