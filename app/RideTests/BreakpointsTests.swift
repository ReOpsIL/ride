import XCTest

final class BreakpointsTests: XCTestCase {
    func testToggleAddsAndRemoves() {
        var set = Breakpoints()
        XCTAssertTrue(set.toggle(path: "/a/main.rs", line: 10))
        XCTAssertEqual(set.lines(path: "/a/main.rs"), [10])
        XCTAssertFalse(set.toggle(path: "/a/main.rs", line: 10))
        XCTAssertTrue(set.isEmpty)
    }

    func testMarksAreSortedAndUnique() {
        var set = Breakpoints()
        set.toggle(path: "/a/main.rs", line: 12)
        set.toggle(path: "/a/main.rs", line: 4)
        set.toggle(path: "/a/main.rs", line: 12)
        set.toggle(path: "/a/main.rs", line: 12)
        XCTAssertEqual(set.marks(path: "/a/main.rs").map(\.line), [4, 12])
    }

    func testEditKeepsLineAndTrims() {
        var set = Breakpoints()
        set.toggle(path: "/a/main.rs", line: 7)
        set.edit(path: "/a/main.rs", line: 7, condition: "  i > 2 ", hitCondition: "  ")
        let mark = set.mark(path: "/a/main.rs", line: 7)
        XCTAssertEqual(mark?.condition, "i > 2")
        XCTAssertNil(mark?.hitCondition)
        XCTAssertEqual(set.marks(path: "/a/main.rs").count, 1)
    }

    func testEditOnMissingLineDoesNothing() {
        var set = Breakpoints()
        set.edit(path: "/a/main.rs", line: 3, condition: "x", hitCondition: nil)
        XCTAssertTrue(set.isEmpty)
    }

    func testVerifyFlagsOnlyReportedLines() {
        var set = Breakpoints()
        set.toggle(path: "/a/main.rs", line: 10)
        set.toggle(path: "/a/main.rs", line: 11)
        set.verify(path: "/a/main.rs", verified: [10])
        XCTAssertEqual(set.mark(path: "/a/main.rs", line: 10)?.verified, true)
        XCTAssertEqual(set.mark(path: "/a/main.rs", line: 11)?.verified, false)
    }

    func testRemoveAllClearsTheFileOnly() {
        var set = Breakpoints()
        set.toggle(path: "/a/main.rs", line: 1)
        set.toggle(path: "/a/util.rs", line: 2)
        set.removeAll(path: "/a/main.rs")
        XCTAssertEqual(set.paths, ["/a/util.rs"])
    }

    func testRoundTripsThroughJSON() throws {
        var set = Breakpoints()
        set.toggle(path: "/a/main.rs", line: 10)
        set.edit(path: "/a/main.rs", line: 10, condition: "n == 3", hitCondition: ">5")
        let data = try JSONEncoder().encode(set)
        let back = try JSONDecoder().decode(Breakpoints.self, from: data)
        XCTAssertEqual(back, set)
        XCTAssertEqual(back.mark(path: "/a/main.rs", line: 10)?.hitCondition, ">5")
    }

    func testWorkspaceStateCarriesBreakpoints() throws {
        var set = Breakpoints()
        set.toggle(path: "/a/main.rs", line: 10)
        let state = WorkspaceState(tabs: [], focusedPath: nil, layout: .defaults, breakpoints: set)
        let data = try JSONEncoder().encode(state)
        let back = try XCTUnwrap(WorkspaceState.decode(data))
        XCTAssertEqual(back.breakpoints, set)
    }

    func testWorkspaceStateWithoutBreakpointsDecodesEmpty() throws {
        let json = Data(#"{"version":1,"tabs":[],"layout":{}}"#.utf8)
        let back = try XCTUnwrap(WorkspaceState.decode(json))
        XCTAssertTrue(back.breakpoints.isEmpty)
    }
}
