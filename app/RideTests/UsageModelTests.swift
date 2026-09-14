import XCTest

final class UsageModelTests: XCTestCase {
    private func row(_ path: String, _ byte: UInt32, scope: Bool) -> UsageRow {
        UsageRow(
            path: path,
            line: byte / 10 + 1,
            byteStart: byte,
            byteEnd: byte + 6,
            enclosingItem: "main",
            enclosingKind: "fn",
            inDefinitionScope: scope
        )
    }

    func testGroupsByFileInFirstSeenOrder() {
        let rows = [
            row("src/main.rs", 30, scope: false),
            row("src/util.rs", 10, scope: false),
            row("src/main.rs", 12, scope: false),
        ]
        let groups = UsageGrouping.group(rows)
        XCTAssertEqual(groups.map(\.path), ["src/main.rs", "src/util.rs"])
        XCTAssertEqual(groups[0].rows.map(\.byteStart), [12, 30])
        XCTAssertEqual(groups[0].count, 2)
        XCTAssertEqual(groups[0].name, "main.rs")
    }

    func testSplitSeparatesDefinitionScope() {
        let rows = [
            row("src/main.rs", 10, scope: true),
            row("src/main.rs", 20, scope: false),
            row("src/util.rs", 30, scope: false),
        ]
        let split = UsageGrouping.split(rows)
        XCTAssertEqual(UsageGrouping.total(split.primary), 1)
        XCTAssertEqual(UsageGrouping.total(split.other), 2)
        XCTAssertEqual(split.primary.first?.path, "src/main.rs")
    }

    func testVisionMapsCountsToLines() {
        let items = [
            VisionItem(name: "record", line: 14),
            VisionItem(name: "count", line: 26),
            VisionItem(name: "unused", line: 40),
        ]
        let counts = ["record": 2, "count": 1, "unused": 0]
        let lines = UsageVision.lines(items: items, counts: counts)
        XCTAssertEqual(lines.map(\.line), [14, 26])
        XCTAssertEqual(lines[0].label, "2 usages")
        XCTAssertEqual(lines[1].label, "1 usage")
    }

    func testVisionSkipsUnknownItems() {
        let lines = UsageVision.lines(items: [VisionItem(name: "x", line: 1)], counts: [:])
        XCTAssertTrue(lines.isEmpty)
    }
}
