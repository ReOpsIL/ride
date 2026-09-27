import XCTest

final class OverlayTests: XCTestCase {
    func testPressingTheOpenOverlayClosesIt() {
        XCTAssertNil(Overlay.toggled(.symbolInFile, pressing: .symbolInFile))
        XCTAssertNil(Overlay.toggled(.quickOpen, pressing: .quickOpen))
    }

    func testPressingAnotherOverlayReplacesTheOpenOne() {
        XCTAssertEqual(Overlay.toggled(.goToLine, pressing: .quickOpen), .quickOpen)
        XCTAssertEqual(Overlay.toggled(nil, pressing: .recentFiles), .recentFiles)
    }

    func testHidingAnOverlayLeavesAnotherOpenOneAlone() {
        XCTAssertEqual(Overlay.setting(.projectFind, .quickOpen, shown: false), .projectFind)
        XCTAssertNil(Overlay.setting(.quickOpen, .quickOpen, shown: false))
        XCTAssertEqual(Overlay.setting(.goToLine, .symbolInProject, shown: true), .symbolInProject)
    }
}
