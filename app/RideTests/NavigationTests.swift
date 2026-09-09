import XCTest

final class NavigationTests: XCTestCase {
    func testWorkspaceContainsFile() {
        let root = URL(fileURLWithPath: "/tmp/proj")
        XCTAssertTrue(WorkspaceFS.contains(root: root, file: URL(fileURLWithPath: "/tmp/proj/src/main.rs")))
        XCTAssertTrue(WorkspaceFS.contains(root: root, file: root))
        XCTAssertFalse(WorkspaceFS.contains(root: root, file: URL(fileURLWithPath: "/tmp/project/src/main.rs")))
        XCTAssertFalse(WorkspaceFS.contains(root: nil, file: URL(fileURLWithPath: "/tmp/proj/a.rs")))
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
