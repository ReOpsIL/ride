import XCTest

final class DiagnosticTidyTests: XCTestCase {
    private func item(_ message: String, _ byte: UInt32, code: String? = nil) -> StoredDiagnostic {
        StoredDiagnostic(path: "/a.c", byteStart: byte, byteEnd: byte + 1, line: 1, column: 1, level: .warning, message: message, code: code)
    }

    func testTidyFindingsSitBesideLiveCompilerDiagnostics() {
        var store = DiagnosticStore()
        store.insert(item("saved", 1))
        store.replaceLive(path: "/a.c", with: [item("live", 2)])
        store.replaceTidy(path: "/a.c", with: [item("tidy", 3, code: "bugprone-sizeof-expression")])
        XCTAssertEqual(store.snapshot.map(\.message), ["live", "tidy"])
        store.replaceLive(path: "/a.c", with: [item("live again", 2)])
        XCTAssertEqual(store.snapshot.map(\.message), ["live again", "tidy"])
        store.replaceTidy(path: "/a.c", with: [])
        XCTAssertEqual(store.snapshot.map(\.message), ["live again"])
    }
}
