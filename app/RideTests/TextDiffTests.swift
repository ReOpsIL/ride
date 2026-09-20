import XCTest

final class TextDiffTests: XCTestCase {
    func testIdenticalTextHasNoEdit() {
        XCTAssertNil(TextDiff.minimalEdit(from: "abc", to: "abc"))
        XCTAssertNil(TextDiff.minimalEdit(from: "", to: ""))
    }

    func testPureAppend() {
        let edit = TextDiff.minimalEdit(from: "abc", to: "abcdef")
        XCTAssertEqual(edit?.range, NSRange(location: 3, length: 0))
        XCTAssertEqual(edit?.text, "def")
    }

    func testDeletionInTheMiddle() {
        let edit = TextDiff.minimalEdit(from: "abcdef", to: "abef")
        XCTAssertEqual(edit?.range, NSRange(location: 2, length: 2))
        XCTAssertEqual(edit?.text, "")
    }

    func testReplacementInTheMiddle() {
        let edit = TextDiff.minimalEdit(from: "abcdef", to: "abXYdef")
        XCTAssertEqual(edit?.range, NSRange(location: 2, length: 1))
        XCTAssertEqual(edit?.text, "XY")
    }

    func testSurrogatePairWidensToWholeScalar() {
        let edit = TextDiff.minimalEdit(from: "a😀b", to: "a😁b")
        XCTAssertEqual(edit?.range, NSRange(location: 1, length: 2))
        XCTAssertEqual(edit?.text, "😁")
    }

    func testDeletedScalarKeepsPairIntact() {
        let edit = TextDiff.minimalEdit(from: "a😀b", to: "ab")
        XCTAssertEqual(edit?.range, NSRange(location: 1, length: 2))
        XCTAssertEqual(edit?.text, "")
    }

    func testReformatTouchesOnlyTheChangedLine() {
        let old = "a\nb\n    c\nd\ne\n"
        let new = "a\nb\n        c\nd\ne\n"
        let edit = TextDiff.minimalEdit(from: old, to: new)
        XCTAssertEqual(edit?.range, NSRange(location: 8, length: 0))
        XCTAssertEqual(edit?.text, "    ")
        let applied = (old as NSString).replacingCharacters(in: edit?.range ?? NSRange(), with: edit?.text ?? "")
        XCTAssertEqual(applied, new)
    }
}
