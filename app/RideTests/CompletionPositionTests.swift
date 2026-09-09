import XCTest

final class CompletionPositionTests: XCTestCase {
    func testMemberAccess() {
        XCTAssertEqual(CompletionPosition.detect(before: "counter."), .memberAccess)
        XCTAssertEqual(CompletionPosition.detect(before: "self.seen."), .memberAccess)
    }

    func testRangeIsNotMemberAccess() {
        XCTAssertNotEqual(CompletionPosition.detect(before: "0.."), .memberAccess)
    }

    func testTypeAfterColon() {
        XCTAssertEqual(CompletionPosition.detect(before: "let m: "), .typePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "seen: "), .typePosition)
    }

    func testPathSeparatorIsNotType() {
        XCTAssertNotEqual(CompletionPosition.detect(before: "std::"), .typePosition)
    }

    func testTypeAfterArrowGenericAndWords() {
        XCTAssertEqual(CompletionPosition.detect(before: "fn f() -> "), .typePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "Vec<"), .typePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "impl "), .typePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "x as "), .typePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "struct "), .typePosition)
    }

    func testReferenceAfterTypeMarker() {
        XCTAssertEqual(CompletionPosition.detect(before: "word: &"), .typePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "word: &mut "), .typePosition)
    }

    func testValuePositions() {
        XCTAssertEqual(CompletionPosition.detect(before: "let x = "), .valuePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "foo("), .valuePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "foo(a, "), .valuePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "return "), .valuePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "fn main() {\n    "), .valuePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "a + "), .valuePosition)
        XCTAssertEqual(CompletionPosition.detect(before: "x;\n    "), .valuePosition)
    }

    func testUnknown() {
        XCTAssertEqual(CompletionPosition.detect(before: "pub fn "), .unknown)
        XCTAssertEqual(CompletionPosition.detect(before: "let "), .unknown)
    }
}
