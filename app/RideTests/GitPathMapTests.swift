import XCTest

final class GitPathMapTests: XCTestCase {
    func testWorkspaceAtTheRepositoryRootKeepsPaths() {
        let map = GitPathMap(repoRoot: "/w/repo", workspace: URL(fileURLWithPath: "/w/repo"))
        XCTAssertEqual(map.workspaceRelative("src/main.rs"), "src/main.rs")
        XCTAssertEqual(map.url("src/main.rs").path, "/w/repo/src/main.rs")
    }

    func testWorkspaceInsideTheRepositoryStripsItsPrefix() {
        let map = GitPathMap(repoRoot: "/w/repo", workspace: URL(fileURLWithPath: "/w/repo/app"))
        XCTAssertEqual(map.workspaceRelative("app/src/lib.rs"), "src/lib.rs")
        XCTAssertNil(map.workspaceRelative("docs/readme.md"))
        XCTAssertEqual(map.url("docs/readme.md").path, "/w/repo/docs/readme.md")
        XCTAssertEqual(map.url("app/src/lib.rs").path, "/w/repo/app/src/lib.rs")
    }

    func testUnrelatedWorkspaceMapsNothing() {
        let map = GitPathMap(repoRoot: "/w/repo", workspace: URL(fileURLWithPath: "/w/repository"))
        XCTAssertNil(map.workspaceRelative("a.rs"))
    }

    func testParentDirectories() {
        let dirs = GitPathMap.parents(of: ["src/a/b.rs", "top.rs"])
        XCTAssertEqual(dirs, ["src", "src/a"])
    }
}
