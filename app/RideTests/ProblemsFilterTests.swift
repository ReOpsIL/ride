import XCTest

final class ProblemsFilterTests: XCTestCase {
    private func diag(_ level: ProblemLevel, _ line: UInt32) -> StoredDiagnostic {
        StoredDiagnostic(path: "/a.rs", byteStart: 0, byteEnd: 1, line: line, column: 1, level: level, message: "m", code: nil)
    }

    func testFiltersSplitErrorsFromEverythingElse() {
        let items = [diag(.error, 1), diag(.warning, 2)]
        XCTAssertEqual(ProblemsFilter().visible(items).count, 2)
        XCTAssertEqual(ProblemsFilter(showErrors: false, showWarnings: true).visible(items).map(\.line), [2])
        XCTAssertEqual(ProblemsFilter(showErrors: true, showWarnings: false).visible(items).map(\.line), [1])
    }

    func testIndentLabelSaysTabsForMakefiles() {
        XCTAssertEqual(IndentLabel.text(language: .make, tabWidth: 4), "Tabs")
        XCTAssertEqual(IndentLabel.text(language: .rust, tabWidth: 2), "Spaces: 2")
    }
}
