import XCTest

final class SelfTestSelectionTests: XCTestCase {
    private let names = ["setup", "indent keeps selection", "debug", "zoom"]

    func testNoFilterRunsEverything() {
        let selection = SelfTestSelection.pick(names, only: nil) { $0 }
        XCTAssertEqual(selection.picked, names)
        XCTAssertEqual(selection.missing, [])
    }

    func testFilterKeepsSetupAndRequestedSteps() {
        let selection = SelfTestSelection.pick(names, only: ["zoom"]) { $0 }
        XCTAssertEqual(selection.picked, ["setup", "zoom"])
        XCTAssertEqual(selection.missing, [])
    }

    func testMisspelledNameIsReportedMissing() {
        let selection = SelfTestSelection.pick(names, only: ["zoon", "debug"]) { $0 }
        XCTAssertEqual(selection.picked, ["setup", "debug"])
        XCTAssertEqual(selection.missing, ["zoon"])
    }
}
