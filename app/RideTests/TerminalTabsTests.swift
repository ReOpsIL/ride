import XCTest

final class TerminalTabsTests: XCTestCase {
    private func selectedItem(_ tabs: TerminalTabs) -> TerminalTabItem? {
        tabs.items.first { $0.id == tabs.selected }
    }

    private func selectedTitle(_ tabs: TerminalTabs) -> String? {
        selectedItem(tabs)?.title
    }

    func testAddSelectsNewTab() {
        var tabs = TerminalTabs()
        let first = TerminalTabItem(title: "one")
        let second = TerminalTabItem(title: "two")
        tabs.add(first)
        tabs.add(second)
        XCTAssertEqual(tabs.count, 2)
        XCTAssertEqual(tabs.selected, second.id)
        XCTAssertEqual(selectedTitle(tabs), "two")
    }

    func testCloseSelectedFallsBackToNeighbour() {
        var tabs = TerminalTabs()
        let a = TerminalTabItem(title: "a")
        let b = TerminalTabItem(title: "b")
        let c = TerminalTabItem(title: "c")
        tabs.add(a)
        tabs.add(b)
        tabs.add(c)
        tabs.select(b.id)
        tabs.close(b.id)
        XCTAssertEqual(tabs.selected, c.id)
        tabs.close(c.id)
        XCTAssertEqual(tabs.selected, a.id)
        tabs.close(a.id)
        XCTAssertNil(tabs.selected)
        XCTAssertTrue(tabs.isEmpty)
    }

    func testCloseOtherTabKeepsSelection() {
        var tabs = TerminalTabs()
        let a = TerminalTabItem(title: "a")
        let b = TerminalTabItem(title: "b")
        tabs.add(a)
        tabs.add(b)
        tabs.close(a.id)
        XCTAssertEqual(tabs.selected, b.id)
        XCTAssertEqual(tabs.count, 1)
    }

    func testSelectAndRenameIgnoreUnknownIds() {
        var tabs = TerminalTabs()
        let a = TerminalTabItem(title: "a")
        tabs.add(a)
        let stranger = UUID()
        tabs.select(stranger)
        tabs.rename(stranger, title: "x")
        tabs.rename(a.id, title: "")
        tabs.close(stranger)
        XCTAssertEqual(tabs.selected, a.id)
        XCTAssertEqual(selectedTitle(tabs), "a")
        XCTAssertEqual(tabs.count, 1)
    }

    func testRenameAndRemoveAll() {
        var tabs = TerminalTabs()
        let a = TerminalTabItem(title: "a", directory: "/tmp")
        tabs.add(a)
        tabs.rename(a.id, title: "zsh")
        XCTAssertEqual(selectedTitle(tabs), "zsh")
        XCTAssertEqual(selectedItem(tabs)?.directory, "/tmp")
        tabs.removeAll()
        XCTAssertTrue(tabs.isEmpty)
        XCTAssertNil(tabs.selected)
    }

    func testTitleForDirectory() {
        XCTAssertEqual(TerminalTabs.title(for: "/Users/x/proj"), "proj")
        XCTAssertEqual(TerminalTabs.title(for: "/"), "shell")
        XCTAssertEqual(TerminalTabs.title(for: nil), "shell")
        XCTAssertEqual(TerminalTabs.title(for: ""), "shell")
    }
}
