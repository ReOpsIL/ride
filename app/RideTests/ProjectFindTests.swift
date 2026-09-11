import XCTest

final class ProjectFindTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ride-find-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("src"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("target"), withIntermediateDirectories: true)
        try "fn main() {\n    let needle = 1;\n}\nfn Needle() {}\n".write(
            to: root.appendingPathComponent("src/main.rs"), atomically: true, encoding: .utf8)
        try "needle in build output\n".write(
            to: root.appendingPathComponent("target/out.txt"), atomically: true, encoding: .utf8)
        try Data([0, 1, 2, 3, 110, 101, 101, 100, 108, 101]).write(to: root.appendingPathComponent("blob.bin"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testFindsCaseInsensitiveLinesWithByteOffsets() {
        let result = ProjectFind.search(root: root, query: "NEEDLE", showHidden: false)
        XCTAssertFalse(result.truncated)
        XCTAssertEqual(result.matches.map(\.line), [2, 4])
        XCTAssertEqual(result.matches[0].byte, 20)
        XCTAssertEqual(result.matches[0].preview, "let needle = 1;")
        XCTAssertTrue(result.matches.allSatisfy { $0.file.lastPathComponent == "main.rs" })
    }

    func testSkipsTargetAndBinary() {
        let result = ProjectFind.search(root: root, query: "needle", showHidden: false)
        XCTAssertFalse(result.matches.contains { $0.file.path.contains("/target/") })
        XCTAssertFalse(result.matches.contains { $0.file.pathExtension == "bin" })
    }

    func testCapMarksTruncated() {
        let result = ProjectFind.search(root: root, query: "needle", showHidden: false, cap: 1)
        XCTAssertTrue(result.truncated)
        XCTAssertEqual(result.matches.count, 1)
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(ProjectFind.search(root: root, query: "  ", showHidden: false).matches.isEmpty)
    }
}
