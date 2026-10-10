import XCTest

final class NavigationTests: XCTestCase {
    func testWorkspaceContainsFile() {
        let root = URL(fileURLWithPath: "/tmp/proj")
        XCTAssertTrue(WorkspaceFS.contains(root: root, file: URL(fileURLWithPath: "/tmp/proj/src/main.rs")))
        XCTAssertTrue(WorkspaceFS.contains(root: root, file: root))
        XCTAssertFalse(WorkspaceFS.contains(root: root, file: URL(fileURLWithPath: "/tmp/project/src/main.rs")))
        XCTAssertFalse(WorkspaceFS.contains(root: nil, file: URL(fileURLWithPath: "/tmp/proj/a.rs")))
    }

    func testSymlinkRootContainsTheRealFile() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ride-symlink-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let real = root.appendingPathComponent("real")
        let file = real.appendingPathComponent("src/main.rs")
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        let link = root.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: real)
        let via = link.appendingPathComponent("src/main.rs")
        XCTAssertEqual(WorkspaceFS.resolvedPath(file), WorkspaceFS.resolvedPath(via))
        XCTAssertTrue(WorkspaceFS.contains(root: link, file: file))
        XCTAssertTrue(WorkspaceFS.contains(root: real, file: via))
        XCTAssertEqual(WorkspaceFS.relativePath(root: link, file: file), "src/main.rs")
        XCTAssertEqual(WorkspaceFS.resolvedPath(WorkspaceFS.spelled(inside: link, file: file)), WorkspaceFS.resolvedPath(via))
        XCTAssertTrue(WorkspaceFS.spelled(inside: link, file: file).path.hasPrefix(link.standardizedFileURL.path))
    }

    func testIdentifierRangeUnderCursor() {
        let text = "let foo_bar = baz();" as NSString
        XCTAssertEqual(IdentifierRange.at(text, index: 6), NSRange(location: 4, length: 7))
        XCTAssertEqual(IdentifierRange.at(text, index: 11), NSRange(location: 4, length: 7))
        XCTAssertNil(IdentifierRange.at(text, index: 12))
        XCTAssertEqual(IdentifierRange.at(text, index: 14), NSRange(location: 14, length: 3))
        XCTAssertNil(IdentifierRange.at("" as NSString, index: 0))
    }
}
