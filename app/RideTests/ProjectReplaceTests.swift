import XCTest

final class ProjectReplaceTests: XCTestCase {
    func testLiteralReplacesEveryHit() {
        let query = "foo"
        let a = hit("/a.rs", "foo foo\nbar", query: query)
        let b = hit("/b.rs", "foo", query: query)
        let edits = ProjectReplace.edits(hits: [a, b], query: query, replacement: "qux")
        XCTAssertEqual(edits.count, 2)
        XCTAssertEqual(text(edits, "/a.rs"), "qux qux\nbar")
        XCTAssertEqual(text(edits, "/b.rs"), "qux")
    }

    func testRegexReplacementUsesCaptureGroups() {
        var options = FindOptions.defaults
        options.regex = true
        let query = "a(\\d+)"
        let file = hit("/a.rs", "a1 a22 a333", query: query, options: options)
        let edits = ProjectReplace.edits(hits: [file], query: query, replacement: "n$1", options: options)
        XCTAssertEqual(edits.first?.text, "n1 n22 n333")
    }

    func testMultipleHitsOnOneLine() {
        let query = "x"
        let file = hit("/a.rs", "x x x", query: query)
        XCTAssertEqual(file.ranges.count, 3)
        let edits = ProjectReplace.edits(hits: [file], query: query, replacement: "y")
        XCTAssertEqual(edits.first?.text, "y y y")
    }

    func testUntickedFileIsUnchanged() {
        let query = "foo"
        let keep = hit("/keep.rs", "foo keep", query: query)
        let skip = hit("/skip.rs", "foo skip", query: query)
        let edits = ProjectReplace.edits(hits: [keep], query: query, replacement: "bar")
        XCTAssertEqual(edits.map { $0.file.lastPathComponent }, ["keep.rs"])
        XCTAssertEqual(edits.first?.text, "bar keep")
        XCTAssertFalse(edits.contains { $0.file == skip.file })
        XCTAssertEqual(skip.text, "foo skip")
    }

    private func hit(_ path: String, _ text: String, query: String, options: FindOptions = .defaults) -> FileHit {
        FileHit(
            file: URL(fileURLWithPath: path),
            text: text,
            ranges: FindMatcher.matches(in: text, query: query, options: options)
        )
    }

    private func text(_ edits: [FileEdit], _ path: String) -> String? {
        edits.first { $0.file.path == path }?.text
    }
}
