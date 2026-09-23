import XCTest

final class ProjectOwnerTests: XCTestCase {
    private let roots = ["/w/lesson01", "/w/lesson02", "/w/lesson02/tools/gen", "/w/lesson1"]

    func testFileBelongsToTheDeepestEnclosingRoot() {
        XCTAssertEqual(ProjectOwner.owner(of: "/w/lesson02/src/main.rs", roots: roots), 1)
        XCTAssertEqual(ProjectOwner.owner(of: "/w/lesson02/tools/gen/src/lib.rs", roots: roots), 2)
    }

    func testPrefixOfADirectoryNameIsNotOwnership() {
        XCTAssertEqual(ProjectOwner.owner(of: "/w/lesson1/src/main.rs", roots: roots), 3)
        XCTAssertEqual(ProjectOwner.owner(of: "/w/lesson011/main.rs", roots: roots), nil)
    }

    func testFileOutsideEveryRootHasNoOwner() {
        XCTAssertNil(ProjectOwner.owner(of: "/w/CURRICULUM.md", roots: roots))
        XCTAssertEqual(ProjectOwner.owner(of: "/w/lesson01", roots: roots), 0)
    }

    func testRootOwnsEverythingBeneathIt() {
        XCTAssertEqual(ProjectOwner.owner(of: "/w/a.rs", roots: ["/w"]), 0)
        XCTAssertEqual(ProjectOwner.owner(of: "/x/a.rs", roots: ["/"]), 0)
    }

    func testTitleIsTheRootRelativeToTheWorkspace() {
        XCTAssertEqual(ProjectOwner.title(root: "/w/extra/c", workspace: "/w"), "extra/c")
        XCTAssertEqual(ProjectOwner.title(root: "/w", workspace: "/w"), "w")
    }
}
