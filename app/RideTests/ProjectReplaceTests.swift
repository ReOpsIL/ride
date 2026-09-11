import XCTest

final class ProjectReplaceTests: XCTestCase {
    func testLiteralReplacesEveryHit() {
        let query = "foo"
        let a = hit("/a.rs", "foo foo\nbar", query: query)
        let b = hit("/b.rs", "foo", query: query)
        let result = ProjectReplace.edits(hits: [a, b], query: query, replacement: "qux")
        XCTAssertEqual(result.edits.count, 2)
        XCTAssertEqual(text(result.edits, "/a.rs"), "qux qux\nbar")
        XCTAssertEqual(text(result.edits, "/b.rs"), "qux")
        XCTAssertTrue(result.skipped.isEmpty)
    }

    func testRegexReplacementUsesCaptureGroups() {
        var options = FindOptions.defaults
        options.regex = true
        let query = "a(\\d+)"
        let file = hit("/a.rs", "a1 a22 a333", query: query, options: options)
        let result = ProjectReplace.edits(hits: [file], query: query, replacement: "n$1", options: options)
        XCTAssertEqual(result.edits.first?.text, "n1 n22 n333")
        XCTAssertTrue(result.skipped.isEmpty)
    }

    func testMultipleHitsOnOneLine() {
        let query = "x"
        let file = hit("/a.rs", "x x x", query: query)
        XCTAssertEqual(file.ranges.count, 3)
        let result = ProjectReplace.edits(hits: [file], query: query, replacement: "y")
        XCTAssertEqual(result.edits.first?.text, "y y y")
    }

    func testUntickedFileIsUnchanged() {
        let query = "foo"
        let keep = hit("/keep.rs", "foo keep", query: query)
        let skip = hit("/skip.rs", "foo skip", query: query)
        let result = ProjectReplace.edits(hits: [keep], query: query, replacement: "bar")
        XCTAssertEqual(result.edits.map { $0.file.lastPathComponent }, ["keep.rs"])
        XCTAssertEqual(result.edits.first?.text, "bar keep")
        XCTAssertFalse(result.edits.contains { $0.file == skip.file })
        XCTAssertEqual(skip.text, "foo skip")
        XCTAssertTrue(result.skipped.isEmpty)
    }

    func testChangedOnDiskFileIsSkipped() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ride-replace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("a.rs")
        let query = "foo"
        try "foo bar\n".write(to: file, atomically: true, encoding: .utf8)
        let preview = hit(file.path, "foo bar\n", query: query)
        XCTAssertFalse(preview.ranges.isEmpty)
        try "changed bar\n".write(to: file, atomically: true, encoding: .utf8)
        let hits = ProjectReplace.refresh([preview], query: query, options: .defaults) {
            ProjectFind.readText($0)
        }
        let result = ProjectReplace.edits(hits: hits, query: query, replacement: "qux")
        XCTAssertTrue(result.edits.isEmpty)
        XCTAssertEqual(result.skipped.map(\.lastPathComponent), ["a.rs"])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "changed bar\n")
    }

    func testSummaryNamesFailedFiles() {
        let skipped = URL(fileURLWithPath: "/stale.rs")
        let failed = URL(fileURLWithPath: "/locked.rs")
        XCTAssertEqual(
            ProjectReplace.summary(matches: 2, files: 1, skipped: [skipped], failed: [failed]),
            "Replaced 2 matches in 1 file. Skipped stale.rs. Failed locked.rs"
        )
        XCTAssertEqual(
            ProjectReplace.summary(matches: 0, files: 0, skipped: [], failed: [failed]),
            "Failed locked.rs"
        )
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
