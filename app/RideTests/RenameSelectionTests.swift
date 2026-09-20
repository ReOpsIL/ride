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
            review: RenameSelection.reviewRows(from: [
                RenamePreviewFile(path: "src/other.rs", count: 3),
                RenamePreviewFile(path: "src/extra.rs", count: 1),
            ])
        )
    }

    func testFilesTickedReviewUntickedByDefault() {
        let s = selection()
        XCTAssertEqual(Set(s.chosenFilePaths), ["src/main.rs", "src/util.rs"])
        XCTAssertEqual(s.chosenFilePaths.count, s.files.count)
        XCTAssertTrue(s.includedReview.isEmpty)
        XCTAssertFalse(s.allReviewSelected)
        XCTAssertEqual(s.chosenEditCount, 3)
        XCTAssertEqual(s.chosenTargetCount, 2)
        XCTAssertTrue(s.canApply)
        XCTAssertFalse(s.showBanner)
    }

    func testUntickFileDropsItFromApply() {
        var s = selection()
        s.setFile("src/util.rs", false)
        XCTAssertEqual(s.chosenFilePaths, ["src/main.rs"])
        XCTAssertEqual(s.chosenEditCount, 2)
        XCTAssertLessThan(s.chosenFilePaths.count, s.files.count)
    }

    func testTickReviewAddsEditsAndTargets() {
        var s = selection()
        s.setReview(0, true)
        XCTAssertEqual(s.chosenReviewIds, [0])
        XCTAssertEqual(s.chosenEditCount, 6)
        XCTAssertEqual(s.chosenTargetCount, 3)
        XCTAssertFalse(s.allReviewSelected)
    }

    func testSelectAllReviewToggles() {
        var s = selection()
        XCTAssertEqual(s.review.count, 2)
        s.selectAllReview(true)
        XCTAssertTrue(s.allReviewSelected)
        XCTAssertTrue(s.isReview(0))
        XCTAssertEqual(s.chosenReviewIds, [0, 1])
        s.selectAllReview(false)
        XCTAssertFalse(s.allReviewSelected)
        XCTAssertTrue(s.chosenReviewIds.isEmpty)
    }

    func testReviewRowsCarryPathAndCount() {
        let rows = RenameSelection.reviewRows(from: [
            RenamePreviewFile(path: "a/b.cpp", count: 7),
            RenamePreviewFile(path: "c/d.rs", count: 1),
        ])
        XCTAssertEqual(rows[0].id, 0)
        XCTAssertEqual(rows[0].path, "a/b.cpp")
        XCTAssertEqual(rows[0].count, 7)
        XCTAssertEqual(rows[0].label, "a/b.cpp")
        XCTAssertEqual(rows[1].id, 1)
        XCTAssertEqual(rows[1].path, "c/d.rs")
        XCTAssertEqual(rows[1].count, 1)
    }

    func testEmptyFilesShowsBannerAndReviewTickEnablesApply() {
        var s = RenameSelection(
            name: "record",
            newName: "logged",
            files: [],
            review: RenameSelection.reviewRows(from: [RenamePreviewFile(path: "src/main.rs", count: 2)])
        )
        XCTAssertTrue(s.showBanner)
        XCTAssertFalse(s.canApply)
        s.setReview(0, true)
        XCTAssertTrue(s.showBanner)
        XCTAssertTrue(s.canApply)
        XCTAssertEqual(s.chosenEditCount, 2)
    }
}
