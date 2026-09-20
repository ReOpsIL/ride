import XCTest

private struct TestSpan: ByteSpan, Equatable {
    let startByte: UInt32
    let endByte: UInt32
    let tag: String
}

final class ByteSpanShiftTests: XCTestCase {
    private let spans = [
        TestSpan(startByte: 0, endByte: 5, tag: "before"),
        TestSpan(startByte: 5, endByte: 10, tag: "straddle"),
        TestSpan(startByte: 8, endByte: 12, tag: "inside"),
        TestSpan(startByte: 12, endByte: 20, tag: "after"),
    ]

    private func shifted(start: UInt32, oldEnd: UInt32, newEnd: UInt32) -> [TestSpan] {
        ByteSpanShift.shifted(spans, start: start, oldEnd: oldEnd, newEnd: newEnd) { span, from, to in
            TestSpan(startByte: from, endByte: to, tag: span.tag)
        }
    }

    func testGrowingReplacementMovesLaterSpans() {
        XCTAssertEqual(
            shifted(start: 6, oldEnd: 10, newEnd: 14),
            [
                TestSpan(startByte: 0, endByte: 5, tag: "before"),
                TestSpan(startByte: 16, endByte: 24, tag: "after"),
            ]
        )
    }

    func testDeletionMovesLaterSpansBack() {
        XCTAssertEqual(
            shifted(start: 6, oldEnd: 12, newEnd: 6),
            [
                TestSpan(startByte: 0, endByte: 5, tag: "before"),
                TestSpan(startByte: 6, endByte: 14, tag: "after"),
            ]
        )
    }

    func testInsertionDropsOnlyStraddlingSpans() {
        XCTAssertEqual(
            shifted(start: 6, oldEnd: 6, newEnd: 9),
            [
                TestSpan(startByte: 0, endByte: 5, tag: "before"),
                TestSpan(startByte: 11, endByte: 15, tag: "inside"),
                TestSpan(startByte: 15, endByte: 23, tag: "after"),
            ]
        )
    }

    func testSpanEndingAtEditStartIsKept() {
        XCTAssertEqual(
            shifted(start: 5, oldEnd: 5, newEnd: 7).first,
            TestSpan(startByte: 0, endByte: 5, tag: "before")
        )
    }

    func testEmptyInputStaysEmpty() {
        let empty: [TestSpan] = []
        let result = ByteSpanShift.shifted(empty, start: 1, oldEnd: 2, newEnd: 3) { span, from, to in
            TestSpan(startByte: from, endByte: to, tag: span.tag)
        }
        XCTAssertTrue(result.isEmpty)
    }
}
