import XCTest
@testable import Ride

final class FindMatcherTests: XCTestCase {
    private let text = "Counter counter COUNTER counters"

    func testCaseInsensitiveByDefault() {
        XCTAssertEqual(FindMatcher.matches(in: text, query: "counter", options: .defaults).count, 4)
    }

    func testCaseSensitiveAndWholeWord() {
        var options = FindOptions.defaults
        options.caseSensitive = true
        XCTAssertEqual(FindMatcher.matches(in: text, query: "counter", options: options).count, 2)
        options.wholeWord = true
        XCTAssertEqual(FindMatcher.matches(in: text, query: "counter", options: options).count, 1)
    }

    func testRegexAndReplacementTemplate() {
        var options = FindOptions.defaults
        options.regex = true
        let found = FindMatcher.matches(in: "a1 b22 c333", query: "[a-z](\\d+)", options: options)
        XCTAssertEqual(found.count, 3)
        XCTAssertEqual(FindMatcher.replacement("$1", options: options), "$1")
        XCTAssertEqual(FindMatcher.replacement("$1", options: .defaults), "\\$1")
        XCTAssertNil(FindMatcher.expression("[", options: options))
    }

    func testNextWrapsAround() {
        let next = FindMatcher.next(in: text, query: "counter", options: .defaults, from: 30, backwards: false)
        XCTAssertEqual(next?.location, 0)
        let previous = FindMatcher.next(in: text, query: "counter", options: .defaults, from: 0, backwards: true)
        XCTAssertEqual(previous?.location, 24)
    }
}
