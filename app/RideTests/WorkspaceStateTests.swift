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
                previewWidth: 400,
                showSidebar: false,
                showProblems: true,
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
}
