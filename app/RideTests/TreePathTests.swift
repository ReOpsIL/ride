import XCTest

final class TreePathTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/w/teacher")

    func testAncestorsRunFromTheTopFolderDownToTheParent() {
        let file = URL(fileURLWithPath: "/w/teacher/lesson02/src/main.rs")
        XCTAssertEqual(
            TreePath.ancestors(of: file, root: root).map(\.path),
            ["/w/teacher/lesson02", "/w/teacher/lesson02/src"]
        )
    }

    func testFileAtTheRootHasNoAncestors() {
        XCTAssertEqual(TreePath.ancestors(of: URL(fileURLWithPath: "/w/teacher/CURRICULUM.md"), root: root), [])
    }

    func testFileOutsideTheRootHasNoAncestors() {
        XCTAssertEqual(TreePath.ancestors(of: URL(fileURLWithPath: "/w/other/src/main.rs"), root: root), [])
        XCTAssertEqual(TreePath.ancestors(of: URL(fileURLWithPath: "/w/teacherx/a.rs"), root: root), [])
    }
}
