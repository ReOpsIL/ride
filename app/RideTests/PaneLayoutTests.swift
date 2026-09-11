import XCTest
@testable import Ride

final class PaneLayoutTests: XCTestCase {
    let a = UUID()
    let b = UUID()
    let c = UUID()

    func testStartsWithOneEmptyFocusedPane() {
        let layout = PaneLayout()
        XCTAssertEqual(layout.panes.count, 1)
        XCTAssertEqual(layout.focused.id, layout.focusedID)
        XCTAssertNil(layout.activeID)
    }

    func testSettingActiveOpensTabInFocusedPane() {
        var layout = PaneLayout()
        layout.activeID = a
        layout.activeID = b
        layout.activeID = a
        XCTAssertEqual(layout.focused.tabs, [a, b])
        XCTAssertEqual(layout.activeID, a)
    }

    func testCloseFallsBackToLastTab() {
        var layout = PaneLayout()
        layout.activeID = a
        layout.activeID = b
        layout.activeID = c
        layout.close(c)
        XCTAssertEqual(layout.activeID, b)
        layout.close(a)
        XCTAssertEqual(layout.focused.tabs, [b])
        layout.close(b)
        XCTAssertNil(layout.activeID)
    }

    func testRetainPrunesMissingBuffers() {
        var layout = PaneLayout()
        layout.activeID = a
        layout.activeID = b
        layout.retain([b])
        XCTAssertEqual(layout.focused.tabs, [b])
        XCTAssertEqual(layout.activeID, b)
    }

    func testSelectFocusesPaneShowingBuffer() {
        var layout = PaneLayout()
        layout.activeID = a
        let first = layout.focusedID
        let second = layout.split()
        layout.activeID = b
        XCTAssertEqual(layout.panes.map(\.id), [first, second])
        layout.select(a)
        XCTAssertEqual(layout.focusedID, first)
        XCTAssertEqual(layout.activeID, a)
        layout.select(c)
        XCTAssertEqual(layout.focusedID, first)
        XCTAssertEqual(layout.pane(first)?.tabs, [a, c])
    }

    func testOpenRemovesTabFromOtherPanes() {
        var layout = PaneLayout()
        layout.activeID = a
        layout.activeID = b
        let first = layout.focusedID
        let second = layout.split()
        layout.open(a, in: second)
        XCTAssertEqual(layout.pane(first)?.tabs, [b])
        XCTAssertEqual(layout.pane(first)?.activeID, b)
        XCTAssertEqual(layout.pane(second)?.tabs, [a])
        XCTAssertEqual(layout.pane(second)?.activeID, a)
        layout.activeID = b
        XCTAssertEqual(layout.pane(first)?.tabs, [])
        XCTAssertNil(layout.pane(first)?.activeID)
        XCTAssertEqual(layout.pane(second)?.tabs, [a, b])
        XCTAssertEqual(layout.activeID, b)
    }

    func testClosePaneMergesTabsIntoNeighbour() {
        var layout = PaneLayout()
        layout.activeID = a
        let first = layout.focusedID
        let second = layout.split()
        layout.activeID = b
        layout.closePane(second)
        XCTAssertEqual(layout.panes.count, 1)
        XCTAssertEqual(layout.focusedID, first)
        XCTAssertEqual(layout.pane(first)?.tabs, [a, b])
        XCTAssertEqual(layout.activeID, a)
    }

    func testClosePaneKeepsLastPane() {
        var layout = PaneLayout()
        layout.activeID = a
        layout.closePane(layout.focusedID)
        XCTAssertEqual(layout.panes.count, 1)
        XCTAssertEqual(layout.activeID, a)
    }

    func testMoveTakesTabToOtherPane() {
        var layout = PaneLayout()
        layout.activeID = a
        let first = layout.focusedID
        let second = layout.split()
        layout.activeID = b
        layout.move(b, to: first)
        XCTAssertEqual(layout.focusedID, first)
        XCTAssertEqual(layout.pane(first)?.tabs, [a, b])
        XCTAssertEqual(layout.pane(second)?.tabs, [])
        XCTAssertEqual(layout.activeID, b)
    }

    func testResetReplacesEverything() {
        var layout = PaneLayout()
        layout.activeID = a
        layout.split()
        layout.reset(tabs: [b, c], active: nil)
        XCTAssertEqual(layout.panes.count, 1)
        XCTAssertEqual(layout.focused.tabs, [b, c])
        XCTAssertEqual(layout.activeID, c)
    }

    func testRestorePanesAssignsTabsAndFocus() {
        var layout = PaneLayout()
        layout.restorePanes([[a, b], [c]], focused: 1)
        XCTAssertEqual(layout.panes.count, 2)
        XCTAssertEqual(layout.panes[0].tabs, [a, b])
        XCTAssertEqual(layout.panes[0].activeID, b)
        XCTAssertEqual(layout.panes[1].tabs, [c])
        XCTAssertEqual(layout.panes[1].activeID, c)
        XCTAssertEqual(layout.focusedID, layout.panes[1].id)
        XCTAssertEqual(layout.activeID, c)
        layout.restorePanes([[a], []], focused: 0)
        XCTAssertEqual(layout.panes[0].tabs, [a])
        XCTAssertEqual(layout.panes[1].tabs, [])
        XCTAssertNil(layout.panes[1].activeID)
        XCTAssertEqual(layout.focusedID, layout.panes[0].id)
    }
}
