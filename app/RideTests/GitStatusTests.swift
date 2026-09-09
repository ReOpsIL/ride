import XCTest

final class GitStatusTests: XCTestCase {
    func testParsesPorcelainPaths() {
        let text = " M src/main.rs\n?? notes.txt\nR  old.rs -> src/new.rs\n?? \"we ird.rs\"\nA  dir/\n"
        let dirty = GitStatus.parse(porcelain: text)
        XCTAssertEqual(dirty, ["src/main.rs", "notes.txt", "src/new.rs", "we ird.rs", "dir"])
    }

    func testParentDirectories() {
        let dirs = GitStatus.parents(of: ["src/a/b.rs", "top.rs"])
        XCTAssertEqual(dirs, ["src", "src/a"])
    }
}
