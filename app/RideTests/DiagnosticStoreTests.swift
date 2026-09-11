import XCTest

final class DiagnosticStoreTests: XCTestCase {
    func testInsertAppearsInSnapshot() {
        var store = DiagnosticStore()
        store.insert(item("/a.c", 4, "unused"))
        store.insert(item("/a.c", 10, "mismatch", level: .warning))
        XCTAssertEqual(store.snapshot.map(\.message), ["unused", "mismatch"])
        XCTAssertEqual(store.clangPaths, ["/a.c"])
    }

    func testReplaceForPathReplacesOnlyThatPath() {
        var store = DiagnosticStore()
        store.insert(item("/a.c", 1, "old-a"))
        store.insert(item("/b.c", 1, "keep-b"))
        store.replace(path: "/a.c", with: [item("/a.c", 8, "new-a"), item("/a.c", 2, "also-a")])
        XCTAssertEqual(messages(store, "/a.c"), ["also-a", "new-a"])
        XCTAssertEqual(messages(store, "/b.c"), ["keep-b"])
        store.replace(path: "/a.c", with: [])
        XCTAssertEqual(store.snapshot.map(\.path), ["/b.c"])
    }

    func testRemovePathDropsClangAndLeavesCargo() {
        var store = DiagnosticStore()
        store.insert(item("/a.c", 4, "clang-a"))
        store.insert(item("/b.c", 4, "clang-b"))
        store.replaceCargo([item("/a.c", 1, "cargo-a"), item("/c.rs", 2, "cargo-c")])
        XCTAssertTrue(store.remove(path: "/a.c"))
        XCTAssertFalse(store.remove(path: "/a.c"))
        XCTAssertEqual(store.snapshot.map(\.message), ["cargo-a", "clang-b", "cargo-c"])
        store.replaceCargo([item("/c.rs", 9, "next")])
        XCTAssertEqual(store.snapshot.map(\.message), ["clang-b", "next"])
    }

    func testRecheckDropsPathsOwnedBySource() {
        var store = DiagnosticStore()
        store.replace(
            from: "/a.c",
            with: [item("/a.c", 1, "in-source"), item("/h.h", 2, "in-header")]
        )
        store.replace(from: "/b.c", with: [item("/b.c", 3, "keep-b")])
        XCTAssertEqual(messages(store, "/h.h"), ["in-header"])
        store.replace(from: "/a.c", with: [])
        XCTAssertEqual(store.snapshot.map(\.message), ["keep-b"])
        XCTAssertEqual(store.clangPaths, ["/b.c"])
    }

    func testRecheckLeavesHeaderOwnedByOtherSource() {
        var store = DiagnosticStore()
        store.replace(from: "/a.c", with: [item("/h.h", 1, "from-a")])
        store.replace(from: "/b.c", with: [item("/h.h", 2, "from-b")])
        store.replace(from: "/a.c", with: [])
        XCTAssertEqual(messages(store, "/h.h"), ["from-b"])
        store.replace(from: "/b.c", with: [item("/b.c", 4, "only-b")])
        XCTAssertEqual(store.snapshot.map(\.message), ["only-b"])
    }

    func testReplaceAllClangDropsPreviousClangAndKeepsCargo() {
        var store = DiagnosticStore()
        store.replace(from: "/a.c", with: [item("/a.c", 1, "old-a"), item("/h.h", 2, "old-h")])
        store.replaceCargo([item("/r.rs", 3, "cargo")])
        store.replaceAllClang(from: "clang-project", with: [item("/b.c", 4, "new-b")])
        XCTAssertEqual(store.snapshot.map(\.message), ["new-b", "cargo"])
        store.replaceAllClang(from: "clang-project", with: [])
        XCTAssertEqual(store.snapshot.map(\.message), ["cargo"])
    }

    func testSnapshotOrderedByPathThenByte() {
        var store = DiagnosticStore()
        store.insert(item("/b.c", 10, "b10"))
        store.insert(item("/a.c", 20, "a20"))
        store.insert(item("/a.c", 5, "a5"))
        store.replaceCargo([item("/a.c", 1, "cargo")])
        XCTAssertEqual(
            store.snapshot.map { "\($0.path):\($0.byteStart):\($0.message)" },
            ["/a.c:1:cargo", "/a.c:5:a5", "/a.c:20:a20", "/b.c:10:b10"]
        )
    }

    private func item(
        _ path: String,
        _ byte: UInt32,
        _ message: String,
        level: ProblemLevel = .error
    ) -> StoredDiagnostic {
        StoredDiagnostic(
            path: path,
            byteStart: byte,
            byteEnd: byte + 1,
            line: 1,
            column: 1,
            level: level,
            message: message,
            code: nil
        )
    }

    private func messages(_ store: DiagnosticStore, _ path: String) -> [String] {
        store.snapshot.filter { $0.path == path }.map(\.message)
    }
}
