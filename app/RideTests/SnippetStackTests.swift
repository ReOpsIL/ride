import XCTest

final class SnippetStackTests: XCTestCase {
    func testSingleSnippetWalksStopsThenFinishesAtFinalCaret() {
        var stack = SnippetStack()
        XCTAssertTrue(stack.push(outer, replacing: NSRange(location: 0, length: 0)))
        XCTAssertEqual(stack.selection, NSRange(location: 4, length: 1))
        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.next(), .select(NSRange(location: 7, length: 1)))
        XCTAssertEqual(stack.next(), .caret(9))
        XCTAssertTrue(stack.isEmpty)
    }

    func testNestedPushSelectsInnerStop() {
        var stack = nested()
        XCTAssertEqual(stack.depth, 2)
        XCTAssertEqual(stack.selection, NSRange(location: 8, length: 1))
    }

    func testCheatSheetInsertPushesOntoOuterStack() {
        var stack = SnippetStack()
        XCTAssertTrue(stack.push(outer, replacing: NSRange(location: 0, length: 0)))
        XCTAssertEqual(stack.depth, 1)
        let placeholder = NSRange(location: 4, length: 1)
        XCTAssertTrue(stack.contains(placeholder))
        XCTAssertTrue(stack.push(SnippetParser.parse("vec![${1:elem}]$0"), replacing: placeholder))
        XCTAssertEqual(stack.depth, 2)
        XCTAssertEqual(stack.selection, NSRange(location: 9, length: 4))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 16, length: 1)))
        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.next(), .caret(18))
        XCTAssertTrue(stack.isEmpty)
    }

    func testInnerNextPopsAndAdvancesOuterWithRangeShift() {
        var stack = nested()
        let later = NSRange(location: 7, length: 1)
        XCTAssertEqual(RangeShift.shifted(later, replacing: NSRange(location: 4, length: 1), with: 6), NSRange(location: 12, length: 1))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 12, length: 1)))
        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.next(), .caret(14))
        XCTAssertTrue(stack.isEmpty)
    }

    func testCancelInnerResumesShiftedOuterPlaceholder() {
        var stack = nested()
        XCTAssertEqual(stack.cancel(), .select(NSRange(location: 4, length: 6)))
        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.next(), .select(NSRange(location: 12, length: 1)))
    }

    func testInnerTypingIsIncludedInPopShift() {
        var stack = nested()
        XCTAssertTrue(stack.textChanged(range: NSRange(location: 8, length: 1), insertedLength: 3))
        XCTAssertEqual(stack.selection, NSRange(location: 8, length: 3))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 14, length: 1)))
        XCTAssertEqual(stack.next(), .caret(16))
    }

    func testCancelAfterInnerTypingUsesNetInsertedLength() {
        var stack = nested()
        XCTAssertTrue(stack.textChanged(range: NSRange(location: 8, length: 1), insertedLength: 3))
        XCTAssertEqual(stack.cancel(), .select(NSRange(location: 4, length: 8)))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 14, length: 1)))
    }

    func testPreviousStaysOnInnerStops() {
        var stack = SnippetStack()
        _ = stack.push(outer, replacing: NSRange(location: 0, length: 0))
        _ = stack.push(SnippetParser.parse("bar(${1:x}, ${2:y})$0"), replacing: NSRange(location: 4, length: 1))
        XCTAssertEqual(stack.selection, NSRange(location: 8, length: 1))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 11, length: 1)))
        stack.previous()
        XCTAssertEqual(stack.selection, NSRange(location: 8, length: 1))
        stack.previous()
        XCTAssertEqual(stack.selection, NSRange(location: 8, length: 1))
        XCTAssertEqual(stack.depth, 2)
    }

    func testEditOutsideInnerStopFails() {
        var stack = nested()
        XCTAssertFalse(stack.textChanged(range: NSRange(location: 0, length: 1), insertedLength: 1))
        XCTAssertEqual(stack.selection, NSRange(location: 8, length: 1))
    }

    func testShiftMovesEveryFrameAndOrigin() {
        var stack = nested()
        stack.shift(range: NSRange(location: 0, length: 0), insertedLength: 3)
        XCTAssertEqual(stack.selection, NSRange(location: 11, length: 1))
        XCTAssertEqual(stack.cancel(), .select(NSRange(location: 7, length: 6)))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 15, length: 1)))
    }

    func testThreeLevelsPopThroughMiddleOntoOuter() {
        var stack = nested()
        XCTAssertTrue(stack.push(SnippetParser.parse("z(${1:q})$0"), replacing: NSRange(location: 8, length: 1)))
        XCTAssertEqual(stack.depth, 3)
        XCTAssertEqual(stack.selection, NSRange(location: 10, length: 1))
        XCTAssertEqual(stack.next(), .select(NSRange(location: 15, length: 1)))
        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.next(), .caret(17))
    }

    func testPushWithoutStopsIsRejected() {
        var stack = SnippetStack()
        XCTAssertFalse(stack.push(SnippetParser.parse("name!($0)"), replacing: NSRange(location: 0, length: 0)))
        XCTAssertTrue(stack.isEmpty)
    }

    func testContainsOnlyCurrentStop() {
        var stack = SnippetStack()
        _ = stack.push(outer, replacing: NSRange(location: 0, length: 0))
        XCTAssertTrue(stack.contains(NSRange(location: 4, length: 1)))
        XCTAssertTrue(stack.contains(NSRange(location: 4, length: 0)))
        XCTAssertFalse(stack.contains(NSRange(location: 7, length: 1)))
        XCTAssertFalse(stack.contains(NSRange(location: 3, length: 2)))
    }

    private var outer: ParsedSnippet {
        SnippetParser.parse("foo(${1:a}, ${2:b})$0")
    }

    private func nested() -> SnippetStack {
        var stack = SnippetStack()
        _ = stack.push(outer, replacing: NSRange(location: 0, length: 0))
        _ = stack.push(SnippetParser.parse("bar(${1:x})$0"), replacing: NSRange(location: 4, length: 1))
        return stack
    }
}
