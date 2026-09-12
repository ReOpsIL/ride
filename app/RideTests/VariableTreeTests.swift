import XCTest

final class VariableTreeTests: XCTestCase {
    func testRootsAreTheOnlyRowsUntilExpanded() {
        var tree = VariableTree()
        let locals = node("Locals", reference: 1)
        tree.replace([locals], of: VariableTree.rootId)
        XCTAssertEqual(tree.rows.map(\.node.name), ["Locals"])
        XCTAssertFalse(tree.isLoaded(locals.id))
        XCTAssertTrue(tree.toggle(locals.id))
        tree.append([node("counter", parent: locals.id)], to: locals.id)
        XCTAssertEqual(tree.rows.map(\.node.name), ["Locals", "counter"])
        XCTAssertEqual(tree.rows.map(\.depth), [0, 1])
    }

    func testCollapseHidesChildrenButKeepsThemLoaded() {
        var tree = VariableTree()
        let locals = node("Locals", reference: 1)
        tree.replace([locals], of: VariableTree.rootId)
        tree.toggle(locals.id)
        tree.append([node("counter", parent: locals.id)], to: locals.id)
        XCTAssertFalse(tree.toggle(locals.id))
        XCTAssertEqual(tree.rows.count, 1)
        XCTAssertTrue(tree.isLoaded(locals.id))
    }

    func testPagingStopsWhenTheCountIsReached() {
        var tree = VariableTree()
        let list = node("list", reference: 2, children: 150)
        tree.replace([list], of: VariableTree.rootId)
        tree.toggle(list.id)
        tree.append(page(0, parent: list.id, count: VariableTree.pageSize), to: list.id, expected: 150)
        XCTAssertEqual(tree.loaded(list.id).count, VariableTree.pageSize)
        XCTAssertTrue(tree.hasMore(list.id))
        XCTAssertEqual(tree.nextPage(of: list.id).start, VariableTree.pageSize)
        tree.append(page(VariableTree.pageSize, parent: list.id, count: 50), to: list.id, expected: 150)
        XCTAssertEqual(tree.loaded(list.id).count, 150)
        XCTAssertFalse(tree.hasMore(list.id))
        XCTAssertEqual(tree.rows.count, 151)
    }

    func testAShortPageEndsThePaging() {
        var tree = VariableTree()
        let list = node("list", reference: 3)
        tree.replace([list], of: VariableTree.rootId)
        tree.append(page(0, parent: list.id, count: 3), to: list.id)
        XCTAssertFalse(tree.hasMore(list.id))
    }

    func testAppendIgnoresDuplicateIds() {
        var tree = VariableTree()
        let list = node("list", reference: 4)
        tree.replace([list], of: VariableTree.rootId)
        tree.append(page(0, parent: list.id, count: 2), to: list.id)
        tree.append(page(0, parent: list.id, count: 2), to: list.id)
        XCTAssertEqual(tree.loaded(list.id).count, 2)
    }

    func testClearDropsEverything() {
        var tree = VariableTree()
        tree.replace([node("Locals", reference: 1)], of: VariableTree.rootId)
        tree.clear()
        XCTAssertTrue(tree.rows.isEmpty)
        XCTAssertFalse(tree.isLoaded(VariableTree.rootId))
    }

    private func node(_ name: String, parent: String = "", index: Int = 0, reference: Int64 = 0, children: Int = 0) -> VariableNode {
        VariableNode(
            id: VariableTree.childId(parent: parent, index: index, name: name),
            name: name,
            value: "v-\(name)",
            typeName: "i32",
            reference: reference,
            childrenCount: children
        )
    }

    private func page(_ start: Int, parent: String, count: Int) -> [VariableNode] {
        (start ..< start + count).map { index in
            VariableNode(
                id: VariableTree.childId(parent: parent, index: index, name: "item"),
                name: "item\(index)",
                value: "\(index)"
            )
        }
    }
}
