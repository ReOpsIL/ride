import XCTest

final class TreeFileOpsTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("tree-ops-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testDuplicateNamesCountUpPastExistingCopies() {
        let taken: Set<String> = ["main copy.rs", "main copy 2.rs"]
        let url = TreeFileOps.duplicateURL(for: dir.appendingPathComponent("main.rs")) { taken.contains($0.lastPathComponent) }
        XCTAssertEqual(url.lastPathComponent, "main copy 3.rs")
        let folder = TreeFileOps.duplicateURL(for: dir.appendingPathComponent("src")) { _ in false }
        XCTAssertEqual(folder.lastPathComponent, "src copy")
    }

    func testNewFileCreatesMissingFolders() throws {
        let url = try TreeFileOps.createFile(named: "sub/x.rs", in: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testExistingNamesAreReportedNotSwallowed() throws {
        _ = try TreeFileOps.createFolder(named: "a", in: dir)
        XCTAssertThrowsError(try TreeFileOps.createFolder(named: "a", in: dir))
        _ = try TreeFileOps.createFile(named: "b.rs", in: dir)
        XCTAssertThrowsError(try TreeFileOps.createFile(named: "b.rs", in: dir))
    }

    func testMovedURLAndContainment() {
        let src = URL(fileURLWithPath: "/w/src")
        XCTAssertTrue(TreePath.contains(src, URL(fileURLWithPath: "/w/src/a.rs")))
        XCTAssertTrue(TreePath.contains(src, src))
        XCTAssertFalse(TreePath.contains(src, URL(fileURLWithPath: "/w/srcx/a.rs")))
        XCTAssertEqual(TreePath.movedURL(URL(fileURLWithPath: "/w/src/a.rs"), from: src, to: URL(fileURLWithPath: "/w/lib"))?.path, "/w/lib/a.rs")
    }
}
