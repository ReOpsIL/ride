import XCTest

final class MatchHighlightTests: XCTestCase {
    func testSubstringMatchIsOneRange() {
        XCTAssertEqual(MatchHighlight.ranges(in: "src/main.rs", query: "main"), [NSRange(location: 4, length: 4)])
        XCTAssertEqual(MatchHighlight.ranges(in: "HashMap", query: "hash"), [NSRange(location: 0, length: 4)])
    }

    func testSubsequenceMatchMergesAdjacentRanges() {
        XCTAssertEqual(
            MatchHighlight.ranges(in: "src/main.rs", query: "smr"),
            [NSRange(location: 0, length: 1), NSRange(location: 4, length: 1), NSRange(location: 9, length: 1)]
        )
        XCTAssertEqual(MatchHighlight.ranges(in: "Counter", query: "cou"), [NSRange(location: 0, length: 3)])
    }

    func testNoMatchOrEmptyQueryIsEmpty() {
        XCTAssertTrue(MatchHighlight.ranges(in: "Counter", query: "xyz").isEmpty)
        XCTAssertTrue(MatchHighlight.ranges(in: "Counter", query: "  ").isEmpty)
    }

    func testSubstringsFindsEveryOccurrence() {
        XCTAssertEqual(
            MatchHighlight.substrings(in: "counter.record(counter)", query: "counter"),
            [NSRange(location: 0, length: 7), NSRange(location: 15, length: 7)]
        )
    }
}
