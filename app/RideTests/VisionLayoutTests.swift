import CoreGraphics
import XCTest

final class VisionLayoutTests: XCTestCase {
    func testLineHeightCeil() {
        XCTAssertEqual(VisionLayout.lineHeight(ascender: 10, descender: -2, leading: 1.2), 14)
    }

    func testIndentCountsSpacesAndTabs() {
        XCTAssertEqual(VisionLayout.indentWidth(prefix: "    fn", spaceWidth: 7, tabWidth: 4), 28)
        XCTAssertEqual(VisionLayout.indentWidth(prefix: "\tfn", spaceWidth: 7, tabWidth: 4), 28)
        XCTAssertEqual(VisionLayout.indentWidth(prefix: "fn", spaceWidth: 7, tabWidth: 4), 0)
    }

    func testLabelRectSitsInExtraBandAtIndent() {
        let rect = VisionLayout.labelRect(
            extraHeight: 16,
            indent: 20,
            labelSize: CGSize(width: 40, height: 10),
            padding: 5
        )
        XCTAssertEqual(rect.origin.x, 25)
        XCTAssertEqual(rect.origin.y, 3)
        XCTAssertEqual(rect.size, CGSize(width: 40, height: 10))
        XCTAssertTrue(rect.contains(CGPoint(x: 30, y: 5)))
        XCTAssertFalse(rect.contains(CGPoint(x: 10, y: 5)))
    }
}
