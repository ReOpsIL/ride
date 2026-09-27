import XCTest

final class DiagnosticStoreTidyTests: XCTestCase {
    func testTidyFindingsSitNextToLiveCompilerDiagnostics() {
        var store = DiagnosticStore()
        store.replace(from: "/a.c", with: [item("/a.c", 1, "save-error", code: nil)])
        store.replaceLive(path: "/a.c", with: [item("/a.c", 2, "live-error", code: nil)])
        store.replaceTidy(path: "/a.c", with: [item("/a.c", 3, "lint", code: "readability-magic-numbers")])
        XCTAssertEqual(store.snapshot.map(\.message), ["live-error", "lint"])
        store.replaceLive(path: "/a.c", with: [])
        XCTAssertEqual(store.snapshot.map(\.message), ["save-error", "lint"])
    }

    func testTidyKeepsOnlyLintFindingsForItsFile() {
        var store = DiagnosticStore()
        store.replaceTidy(path: "/a.c", with: [
            item("/a.c", 1, "compiler", code: nil),
            item("/a.c", 2, "diag", code: "clang-diagnostic-unused-variable"),
            item("/b.c", 3, "other file", code: "bugprone-branch-clone"),
            item("/a.c", 4, "lint", code: "bugprone-branch-clone"),
        ])
        XCTAssertEqual(store.snapshot.map(\.message), ["lint"])
        XCTAssertEqual(store.clangPaths, ["/a.c"])
    }

    func testRemoveAndEmptyTidyClearTheSlot() {
        var store = DiagnosticStore()
        store.replaceTidy(path: "/a.c", with: [item("/a.c", 1, "lint", code: "misc-x")])
        store.replaceTidy(path: "/a.c", with: [])
        XCTAssertTrue(store.snapshot.isEmpty)
        store.replaceTidy(path: "/a.c", with: [item("/a.c", 1, "lint", code: "misc-x")])
        XCTAssertTrue(store.remove(path: "/a.c"))
        XCTAssertTrue(store.snapshot.isEmpty)
    }

    private func item(_ path: String, _ byte: UInt32, _ message: String, code: String?) -> StoredDiagnostic {
        StoredDiagnostic(path: path, byteStart: byte, byteEnd: byte + 1, line: 1, column: 1, level: .warning, message: message, code: code)
    }
}
