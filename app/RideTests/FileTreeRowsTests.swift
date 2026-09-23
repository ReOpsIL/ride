import XCTest

final class FileTreeRowsTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for rel in ["a/src/main.rs", "a/Cargo.toml", "b/src/main.rs", "notes.md"] {
            let url = root.appendingPathComponent(rel)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testCollapsedFoldersHideTheirChildren() {
        let nodes = WorkspaceFS.children(of: root, showHidden: false)
        XCTAssertEqual(FileTreeRows.visible(nodes, expanded: []).map(\.node.name), ["a", "b", "notes.md"])
    }

    func testExpandedFoldersListChildrenOneLevelDeeper() {
        let nodes = WorkspaceFS.children(of: root, showHidden: false)
        let a = nodes[0]
        a.loadChildren()
        a.children.first { $0.name == "src" }?.loadChildren()
        let src = a.url.appendingPathComponent("src").standardizedFileURL
        let rows = FileTreeRows.visible(nodes, expanded: [a.url, src])
        XCTAssertEqual(rows.map(\.node.name), ["a", "Cargo.toml", "src", "main.rs", "b", "notes.md"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 1, 2, 0, 0])
    }

    func testProjectMarkPrefersActive() {
        XCTAssertEqual(TreeProjectMark(path: "/w/a", roots: ["/w/a", "/w/b"], active: "/w/a"), .active)
        XCTAssertEqual(TreeProjectMark(path: "/w/b", roots: ["/w/a", "/w/b"], active: "/w/a"), .project)
        XCTAssertEqual(TreeProjectMark(path: "/w/c", roots: ["/w/a", "/w/b"], active: "/w/a"), .none)
    }
}
