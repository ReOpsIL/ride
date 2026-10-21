import XCTest

final class AttachModelTests: XCTestCase {
    private let rows = [
        ProcessRow(pid: 31550, parent: 31548, name: "debugger-lab", path: "/w/target/debug/debugger-lab"),
        ProcessRow(pid: 31548, parent: 31547, name: "debugger-lab", path: "./target/debug/debugger-lab"),
        ProcessRow(pid: 900, parent: 1, name: "Ride", path: "/Applications/Ride.app/Contents/MacOS/Ride"),
        ProcessRow(pid: 364, parent: 1, name: "IOUIAgent", path: "/System/IOUIAgent"),
    ]

    func testFilterMatchesNamesAndPidPrefixes() {
        XCTAssertEqual(ProcessFilter.matching(rows, query: "  ").count, 4)
        XCTAssertEqual(ProcessFilter.matching(rows, query: "LAB").map(\.pid), [31550, 31548])
        XCTAssertEqual(ProcessFilter.matching(rows, query: "3155").map(\.pid), [31550])
        XCTAssertEqual(ProcessFilter.matching(rows, query: "36").map(\.pid), [364])
    }

    func testLoadDropsRideAndAStaleSelection() {
        let model = AttachModel()
        model.selection = 42
        model.load(rows, excluding: 900)
        XCTAssertFalse(model.rows.contains { $0.pid == 900 })
        XCTAssertNil(model.selection)
        XCTAssertFalse(model.loading)
    }

    func testAChosenProcessKeepsOnlyAnAbsoluteProgramPath() {
        let model = AttachModel()
        model.load(rows, excluding: 900)
        XCTAssertNil(model.choice)
        model.selection = 31550
        XCTAssertEqual(model.choice, .pid(31550, program: "/w/target/debug/debugger-lab"))
        model.selection = 31548
        XCTAssertEqual(model.choice, .pid(31548, program: nil))
    }

    func testWaitingNeedsAName() {
        let model = AttachModel()
        model.mode = .waitFor
        model.waitName = "  "
        XCTAssertNil(model.choice)
        model.waitName = " debugger-lab "
        XCTAssertEqual(model.choice, .waitFor("debugger-lab"))
    }

    func testOpenSuggestsAWaitNameOnceAndRefreshes() {
        let model = AttachModel()
        var refreshed = 0
        model.onRefresh = { refreshed += 1 }
        model.open(waitName: "/w/target/debug/debugger-lab")
        XCTAssertTrue(model.visible)
        XCTAssertTrue(model.loading)
        XCTAssertEqual(refreshed, 1)
        model.waitName = "other"
        model.open(waitName: "/w/target/debug/debugger-lab")
        XCTAssertEqual(model.waitName, "other")
        XCTAssertEqual(model.mode, .process)
    }

    func testAttachHandsOverTheChoiceAndCloses() {
        let model = AttachModel()
        var chosen: AttachChoice?
        model.onAttach = { chosen = $0 }
        model.visible = true
        model.attach()
        XCTAssertNil(chosen)
        XCTAssertTrue(model.visible)
        model.mode = .waitFor
        model.waitName = "debugger-lab"
        model.attach()
        XCTAssertEqual(chosen, .waitFor("debugger-lab"))
        XCTAssertFalse(model.visible)
    }
}
