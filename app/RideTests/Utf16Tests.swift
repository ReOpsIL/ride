import XCTest

final class Utf16Tests: XCTestCase {
    private let text = "let é = \"🦀\"; ascii"

    func testRoundTripAtEveryCharacterBoundary() {
        var indices = Array(text.indices)
        indices.append(text.endIndex)
        for index in indices {
            let u16 = text.utf16.distance(from: text.startIndex, to: index)
            let u8 = text.utf8.distance(from: text.startIndex, to: index)
            XCTAssertEqual(Utf16.utf8Offset(in: text, utf16: u16), u8)
            XCTAssertEqual(Utf16.utf16Offset(in: text, utf8: u8), u16)
        }
    }

    func testAccentIsTwoBytesOneUnit() {
        XCTAssertEqual(Utf16.utf8Offset(in: text, utf16: 5), 6)
        XCTAssertEqual(Utf16.utf16Offset(in: text, utf8: 6), 5)
    }

    func testCrabIsFourBytesTwoUnits() {
        let start = text.utf16.distance(from: text.startIndex, to: text.firstIndex(of: "🦀")!)
        let startByte = Utf16.utf8Offset(in: text, utf16: start)
        XCTAssertEqual(Utf16.utf8Offset(in: text, utf16: start + 2), startByte + 4)
        XCTAssertEqual(Utf16.utf16Offset(in: text, utf8: startByte + 4), start + 2)
    }

    func testNsRangeCoversCrab() {
        let start = text.utf8.distance(from: text.startIndex, to: text.firstIndex(of: "🦀")!)
        let range = Utf16.nsRange(in: text, startByte: UInt32(start), endByte: UInt32(start + 4))
        XCTAssertEqual(range.length, 2)
        XCTAssertEqual((text as NSString).substring(with: range), "🦀")
    }

    func testOffsetsClamp() {
        XCTAssertEqual(Utf16.utf8Offset(in: text, utf16: 999), text.utf8.count)
        XCTAssertEqual(Utf16.utf16Offset(in: text, utf8: -1), 0)
    }
}
