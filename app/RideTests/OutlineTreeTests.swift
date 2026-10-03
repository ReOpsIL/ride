import XCTest

final class OutlineTreeTests: XCTestCase {
    private func row(_ name: String, _ kind: String, _ start: UInt32, _ end: UInt32, scope: OutlineRow.Scope? = nil) -> OutlineRow {
        OutlineRow(name: name, kindLabel: kind, startByte: start, endByte: end, nameStartByte: start, scope: scope)
    }

    private var rows: [OutlineRow] {
        let tcp = OutlineRow.Scope(label: "impl Protocol for Tcp", startByte: 100, endByte: 200)
        let udp = OutlineRow.Scope(label: "impl Protocol for Udp", startByte: 210, endByte: 300)
        return [
            row("Protocol", "trait", 0, 60),
            row("name", "method", 20, 40),
            row("Tcp", "struct", 70, 90),
            row("name", "method", 110, 150, scope: tcp),
            row("summary", "method", 160, 190, scope: tcp),
            row("name", "method", 220, 260, scope: udp),
            row("describe", "fn", 310, 400),
        ]
    }

    func testMembersNestUnderTheirTraitAndImplBlock() {
        let nodes = OutlineTree.nodes(rows)
        XCTAssertEqual(nodes.map(\.name), ["Protocol", "name", "Tcp", "impl Protocol for Tcp", "name", "summary", "impl Protocol for Udp", "name", "describe"])
        XCTAssertEqual(nodes.map(\.depth), [0, 1, 0, 0, 1, 1, 0, 1, 0])
        XCTAssertEqual(nodes.map(\.hasChildren), [true, false, false, true, false, false, true, false, false])
        XCTAssertEqual(nodes[3].kindLabel, OutlineTree.scopeKind)
        XCTAssertEqual(nodes[3].startByte, 100)
    }

    func testIdsAreUniqueAndStableAcrossShifts() {
        let nodes = OutlineTree.nodes(rows)
        XCTAssertEqual(Set(nodes.map(\.id)).count, nodes.count)
        let shifted = rows.map { row($0.name, $0.kindLabel, $0.startByte + 5, $0.endByte + 5, scope: $0.scope.map { .init(label: $0.label, startByte: $0.startByte + 5, endByte: $0.endByte + 5) }) }
        XCTAssertEqual(OutlineTree.nodes(shifted).map(\.id), nodes.map(\.id))
    }

    func testCollapsedNodesHideTheirSubtree() {
        let nodes = OutlineTree.nodes(rows)
        let visible = OutlineTree.visible(nodes, collapsed: [nodes[0].id, nodes[3].id])
        XCTAssertEqual(visible.map(\.name), ["Protocol", "Tcp", "impl Protocol for Tcp", "impl Protocol for Udp", "name", "describe"])
    }

    func testRepeatedNamesInOneParentGetDistinctIds() {
        let nodes = OutlineTree.nodes([row("f", "fn", 0, 10), row("f", "fn", 20, 30)])
        XCTAssertNotEqual(nodes[0].id, nodes[1].id)
    }
}
