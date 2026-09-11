import XCTest

final class WorkspaceStateStoreTests: XCTestCase {
    func testCancelPendingDropsEmptySnapshot() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = WorkspaceStateStore(supportDir: dir, delay: 0.05)
        let root = URL(fileURLWithPath: "/proj")
        let filled = WorkspaceState(
            tabs: [TabState(path: "/proj/a.rs", caretByte: 0, scrollLine: 1, folds: [])],
            focusedPath: "/proj/a.rs",
            layout: .defaults
        )
        let empty = WorkspaceState(tabs: [], focusedPath: nil, layout: .defaults)
        store.save(filled, root: root)
        store.scheduleSave(empty, root: root)
        store.cancelPending()
        store.scheduleSave(filled, root: root)
        let exp = expectation(description: "debounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(store.load(root: root)?.tabs.map(\.path), ["/proj/a.rs"])
    }
}
