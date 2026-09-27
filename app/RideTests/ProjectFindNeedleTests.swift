import XCTest

final class ProjectFindNeedleTests: XCTestCase {
    func testEdgeSpacesAreKeptAndBlankQueriesDropped() {
        XCTAssertEqual(ProjectFind.needle(" = "), " = ")
        XCTAssertNil(ProjectFind.needle("   "))
        XCTAssertNil(ProjectFind.needle(""))
    }

    func testSpacedQueryMatchesOnlySpacedText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("needle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "let a = 1;\nlet b=2;\n".write(to: root.appendingPathComponent("a.rs"), atomically: true, encoding: .utf8)
        let result = ProjectFind.search(root: root, query: " = ", showHidden: false)
        XCTAssertEqual(result.matches.map(\.line), [1])
    }
}
