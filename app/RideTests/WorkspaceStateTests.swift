import XCTest

final class WorkspaceStateTests: XCTestCase {
    func testRoundTripThroughJSON() throws {
        let original = WorkspaceState(
            tabs: [
                TabState(path: "/proj/src/main.rs", caretByte: 42, scrollLine: 9, folds: [10, 80]),
                TabState(path: "/proj/src/util.rs", caretByte: 0, scrollLine: 1, folds: []),
            ],
            focusedPath: "/proj/src/main.rs",
            layout: LayoutState(
                sidebarWidth: 240,
                outlineWidth: 200,
                problemsHeight: 160,
                runOutputHeight: 220,
                previewWidth: 400,
                showSidebar: false,
                showProblems: true,
                showRunOutput: true,
                showPreview: true,
                outlinePanel: false
            ),
            split: SplitState(ratio: 0.4)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkspaceState.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(WorkspaceState.decode(data), original)
    }

    func testMissingOptionalFieldsDecode() throws {
        let json = """
        {"version":1,"tabs":[{"path":"/a.rs"}]}
        """
        let state = try XCTUnwrap(WorkspaceState.decode(Data(json.utf8)))
        XCTAssertEqual(state.version, 1)
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.tabs[0].path, "/a.rs")
        XCTAssertEqual(state.tabs[0].caretByte, 0)
        XCTAssertEqual(state.tabs[0].scrollLine, 1)
        XCTAssertEqual(state.tabs[0].folds, [])
        XCTAssertNil(state.focusedPath)
        XCTAssertEqual(state.layout, .defaults)
        XCTAssertNil(state.split)
    }

    func testVersionMismatchYieldsNil() {
        let unknown = """
        {"version":2,"tabs":[{"path":"/a.rs","caretByte":3}]}
        """
        XCTAssertNil(WorkspaceState.decode(Data(unknown.utf8)))
        let missing = """
        {"tabs":[]}
        """
        XCTAssertNil(WorkspaceState.decode(Data(missing.utf8)))
        XCTAssertNil(WorkspaceState.decode(Data("not json".utf8)))
    }

    func testCaretPastEofClamps() {
        let tab = TabState(path: "/a.rs", caretByte: 99, scrollLine: 0, folds: [1, 50])
        let clamped = tab.clamped(toUtf8Count: 4)
        XCTAssertEqual(clamped.caretByte, 4)
        XCTAssertEqual(clamped.scrollLine, 1)
        XCTAssertEqual(clamped.folds, [1])
        XCTAssertEqual(tab.folds(keeping: [80, 1]), [1])
    }

    func testSplitStateRoundTripsPanesAndFocus() throws {
        let split = SplitState(panes: [["/a.rs", "/b.rs"], ["/c.rs"]], focused: 1, ratio: 0.35)
        let original = WorkspaceState(
            tabs: [
                TabState(path: "/a.rs", caretByte: 0, scrollLine: 1, folds: []),
                TabState(path: "/c.rs", caretByte: 4, scrollLine: 2, folds: []),
            ],
            focusedPath: "/c.rs",
            layout: .defaults,
            split: split
        )
        let decoded = try JSONDecoder().decode(WorkspaceState.self, from: try JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(WorkspaceState.decode(try JSONEncoder().encode(original)), original)
    }

    func testSplitStateMissingPanesAndFocusDecode() throws {
        let json = """
        {"version":1,"tabs":[{"path":"/a.rs"}],"split":{"ratio":0.4}}
        """
        let state = try XCTUnwrap(WorkspaceState.decode(Data(json.utf8)))
        XCTAssertEqual(state.split?.ratio, 0.4)
        XCTAssertEqual(state.split?.panes, [])
        XCTAssertEqual(state.split?.focused, 0)
    }

    func testSplitCaptureRestoreRoundTrip() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        var layout = PaneLayout()
        layout.activeID = a
        layout.activeID = b
        let right = layout.split()
        layout.open(c, in: right)
        let paths: [UUID: String] = [a: "/a.rs", b: "/b.rs", c: "/c.rs"]
        let split = SplitState.from(
            ratio: 0.4,
            panes: layout.panes,
            focused: layout.focusedID,
            pathOf: { paths[$0] }
        )
        XCTAssertEqual(split.panes, [["/a.rs", "/b.rs"], ["/c.rs"]])
        XCTAssertEqual(split.focused, 1)
        XCTAssertEqual(split.ratio, 0.4)
        let ids = Dictionary(uniqueKeysWithValues: paths.map { ($0.value, $0.key) })
        let tabs = split.tabs(ids: ids, leftover: [a, b, c])
        XCTAssertEqual(tabs, [[a, b], [c]])
        var restored = PaneLayout()
        restored.restorePanes(tabs, focused: split.focused)
        XCTAssertEqual(restored.panes.map(\.tabs), [[a, b], [c]])
        XCTAssertEqual(restored.focusedID, restored.panes[1].id)
        XCTAssertEqual(restored.activeID, c)
        let legacy = SplitState(ratio: 0.5)
        XCTAssertEqual(legacy.tabs(ids: ids, leftover: [a, b, c]), [[a, b, c], []])
    }

    func testSplitStateDedupesPathListedInTwoPanes() {
        let a = UUID()
        let b = UUID()
        let split = SplitState(panes: [["/a.rs", "/b.rs"], ["/a.rs"]], focused: 1, ratio: 0.5)
        let ids = ["/a.rs": a, "/b.rs": b]
        XCTAssertEqual(split.tabs(ids: ids, leftover: [a]), [[a, b], []])
    }
}
