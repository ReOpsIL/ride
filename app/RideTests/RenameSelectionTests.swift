import XCTest

final class RenameSelectionTests: XCTestCase {
    private func selection() -> RenameSelection {
        RenameSelection(
            name: "record",
            newName: "logged",
            files: [
                RenamePreviewFile(path: "src/main.rs", count: 2),
                RenamePreviewFile(path: "src/util.rs", count: 1),
            ],
            review: RenameSelection.reviewRows(from: ["src/other.rs:12", "src/other.rs:20"])
        )
    }

    func testFilesTickedReviewUntickedByDefault() {
        let s = selection()
        XCTAssertEqual(Set(s.chosenFilePaths), ["src/main.rs", "src/util.rs"])
        XCTAssertTrue(s.allFilesSelected)
        XCTAssertTrue(s.includedReview.isEmpty)
        XCTAssertFalse(s.allReviewSelected)
        XCTAssertEqual(s.chosenEditCount, 3)
        XCTAssertTrue(s.canApply)
        XCTAssertFalse(s.showBanner)
    }

    func testUntickFileDropsItFromApply() {
        var s = selection()
        s.setFile("src/util.rs", false)
        XCTAssertEqual(s.chosenFilePaths, ["src/main.rs"])
        XCTAssertEqual(s.chosenEditCount, 2)
        XCTAssertFalse(s.allFilesSelected)
    }

    func testSelectAllReviewToggles() {
        var s = selection()
        XCTAssertEqual(s.review.count, 2)
        s.selectAllReview(true)
        XCTAssertTrue(s.allReviewSelected)
        XCTAssertTrue(s.isReview(0))
        s.selectAllReview(false)
        XCTAssertFalse(s.allReviewSelected)
    }

    func testReviewRowsParseTrailingLine() {
        let rows = RenameSelection.reviewRows(from: ["a/b.cpp:7", "noline"])
        XCTAssertEqual(rows[0].path, "a/b.cpp")
        XCTAssertEqual(rows[0].line, 7)
        XCTAssertEqual(rows[0].label, "a/b.cpp:7")
        XCTAssertEqual(rows[1].path, "noline")
        XCTAssertEqual(rows[1].line, 0)
        XCTAssertEqual(rows[1].label, "noline")
    }

    func testEmptyFilesShowsBannerAndBlocksApply() {
        let s = RenameSelection(
            name: "record",
            newName: "logged",
            files: [],
            review: RenameSelection.reviewRows(from: ["src/main.rs:3"])
        )
        XCTAssertTrue(s.filesEmpty)
        XCTAssertTrue(s.showBanner)
        XCTAssertFalse(s.canApply)
    }
}
