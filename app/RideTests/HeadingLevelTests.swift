import XCTest

final class HeadingLevelTests: XCTestCase {
    func testLevels() {
        XCTAssertEqual(HeadingLevel.of("# Title\n"), 1)
        XCTAssertEqual(HeadingLevel.of("## Two"), 2)
        XCTAssertEqual(HeadingLevel.of("###### Six"), 6)
        XCTAssertEqual(HeadingLevel.of("####### Seven"), 6)
        XCTAssertEqual(HeadingLevel.of("Setext\n====="), 1)
        XCTAssertEqual(HeadingLevel.of("  ## indented"), 2)
    }

    func testScaleDecreasesWithLevel() {
        XCTAssertGreaterThan(HeadingLevel.scale(1), HeadingLevel.scale(2))
        XCTAssertGreaterThan(HeadingLevel.scale(2), HeadingLevel.scale(3))
        XCTAssertGreaterThan(HeadingLevel.scale(3), HeadingLevel.scale(4))
        XCTAssertEqual(HeadingLevel.scale(4), HeadingLevel.scale(6))
    }
}
