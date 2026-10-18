import XCTest

final class OverlayStoreTests: XCTestCase {
    func testSameVersionKeepsTheShiftedAndStaleState() {
        let text = String(repeating: "a", count: 40)
        var store = OverlayStore()
        let item = sample(10, 14)
        store.reload(version: 2, diagnostics: [item])
        store.shift(before: text, range: NSRange(location: 0, length: 0), inserted: "zzzz")
        XCTAssertEqual(store.entries[0].diagnostic.primary.byteStart, 14)
        XCTAssertFalse(store.entries[0].stale)
        store.reload(version: 2, diagnostics: [item])
        XCTAssertEqual(store.entries[0].diagnostic.primary.byteStart, 14)
        XCTAssertFalse(store.entries[0].stale)
        store.shift(before: text, range: NSRange(location: 14, length: 1), inserted: "q")
        XCTAssertTrue(store.entries[0].stale)
        XCTAssertEqual(store.entries[0].diagnostic.primary.byteStart, 14)
        store.reload(version: 2, diagnostics: [item])
        XCTAssertTrue(store.entries[0].stale)
        XCTAssertEqual(store.entries[0].diagnostic.primary.byteStart, 14)
    }

    func testNewVersionResetsTheShiftedAndStaleState() {
        let text = String(repeating: "a", count: 40)
        var store = OverlayStore()
        let item = sample(10, 14)
        store.reload(version: 2, diagnostics: [item])
        store.shift(before: text, range: NSRange(location: 0, length: 0), inserted: "zzzz")
        store.shift(before: text, range: NSRange(location: 14, length: 1), inserted: "q")
        let replacement = sample(2, 6)
        store.reload(version: 3, diagnostics: [replacement])
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertFalse(store.entries[0].stale)
        XCTAssertEqual(store.entries[0].diagnostic.primary.byteStart, 2)
        XCTAssertEqual(store.version, 3)
    }

    private func sample(_ start: Int, _ end: Int) -> StoredDiagnostic {
        StoredDiagnostic(
            primary: StoredLabel(
                path: "main.rs",
                byteStart: UInt32(start),
                byteEnd: UInt32(end),
                lineStart: 1,
                lineEnd: 1,
                column: 1,
                text: "rows",
                macroName: nil
            ),
            level: .error,
            message: "m",
            code: "E0382"
        )
    }
}
