import XCTest

final class ShortcutColumnsTests: XCTestCase {
    private func group(_ id: String, _ rows: Int) -> ShortcutGroup {
        ShortcutGroup(id: id, entries: (0..<rows).map { ShortcutEntry("\(id)\($0)", "\(id) \($0)", []) })
    }

    func testTallestColumnStaysNearTheAverage() {
        let columns = ShortcutColumns.balance(Shortcuts.groups, into: 3)
        let heights = columns.map { $0.reduce(0) { $0 + ShortcutColumns.height($1) } }
        let total = Shortcuts.groups.reduce(0) { $0 + ShortcutColumns.height($1) }
        XCTAssertEqual(heights.reduce(0, +), total)
        XCTAssertLessThanOrEqual(heights.max() ?? 0, total / 3 + 4)
    }

    func testColumnsKeepMenuOrder() {
        let groups = [group("A", 2), group("B", 9), group("C", 3), group("D", 4)]
        let columns = ShortcutColumns.balance(groups, into: 2)
        XCTAssertEqual(columns.map { $0.map(\.id) }, [["A", "C", "D"], ["B"]])
    }

    func testEveryGroupAppearsOnce() {
        let ids = ShortcutColumns.balance(Shortcuts.groups, into: 3).flatMap { $0.map(\.id) }
        XCTAssertEqual(ids.sorted(), Shortcuts.groups.map(\.id).sorted())
    }
}
