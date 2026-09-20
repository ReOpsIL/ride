import XCTest

final class HierarchyModelTests: XCTestCase {
    func testSetRootExpandsAndShowsChildren() {
        var model = HierarchyModel()
        let root = node("", "record", path: "util.rs", byte: 40)
        let a = node(root.id, "main", path: "main.rs", byte: 120)
        let b = node(root.id, "main", path: "main.rs", byte: 150)
        _ = model.begin(.callers)
        model.setRoot(root, children: [a, b])
        XCTAssertEqual(model.rootName, "record")
        XCTAssertEqual(model.childCount, 2)
        XCTAssertEqual(model.rows.map(\.node.name), ["record", "main", "main"])
        XCTAssertEqual(model.rows.map(\.depth), [0, 1, 1])
        XCTAssertTrue(model.isExpanded(root.id))
        XCTAssertTrue(model.finished)
        XCTAssertFalse(model.running)
    }

    func testCollapseHidesChildrenButKeepsThemLoaded() {
        var model = HierarchyModel()
        let root = node("", "record", path: "util.rs", byte: 40)
        let child = node(root.id, "main", path: "main.rs", byte: 120)
        model.setRoot(root, children: [child])
        model.collapse(root.id)
        XCTAssertEqual(model.rows.map(\.node.name), ["record"])
        XCTAssertTrue(model.isLoaded(root.id))
        XCTAssertEqual(model.loaded(root.id).map(\.name), ["main"])
        XCTAssertFalse(model.expand(root.id))
        XCTAssertEqual(model.rows.count, 2)
    }

    func testExpandOfUnloadedChildAsksForAFetch() {
        var model = HierarchyModel()
        let root = node("", "record", path: "util.rs", byte: 40)
        let child = node(root.id, "main", path: "main.rs", byte: 120)
        model.setRoot(root, children: [child])
        XCTAssertTrue(model.expand(child.id))
        XCTAssertTrue(model.isExpanded(child.id))
        XCTAssertFalse(model.isLoaded(child.id))
        let nested = node(child.id, "setup", path: "lib.rs", byte: 8)
        model.attach([nested], to: child.id)
        XCTAssertEqual(model.rows.map(\.node.name), ["record", "main", "setup"])
        XCTAssertEqual(model.rows.map(\.depth), [0, 1, 2])
        XCTAssertFalse(model.expand(child.id))
    }

    func testAttachDropsCycleByPathAndByte() {
        var model = HierarchyModel()
        let root = node("", "bar", path: "bar.rs", byte: 1)
        let foo = node(root.id, "foo", path: "foo.rs", byte: 20)
        model.setRoot(root, children: [foo])
        XCTAssertTrue(model.expand(foo.id))
        let cycle = node(foo.id, "bar", path: "bar.rs", byte: 1)
        let other = node(foo.id, "baz", path: "baz.rs", byte: 9)
        model.attach([cycle, other], to: foo.id)
        XCTAssertEqual(model.loaded(foo.id).map(\.name), ["baz"])
    }

    func testAttachDropsDuplicateCycleKeys() {
        var model = HierarchyModel()
        let root = node("", "record", path: "util.rs", byte: 40)
        let a = node(root.id, "main", path: "main.rs", byte: 120)
        let dup = node(root.id, "main", path: "main.rs", byte: 120)
        model.setRoot(root, children: [a, dup])
        XCTAssertEqual(model.childCount, 1)
    }

    func testDepthSixCannotExpand() {
        var model = HierarchyModel()
        let nodes = chain(count: 7)
        model.setRoot(nodes[0], children: [nodes[1]])
        for index in 1 ..< 6 {
            XCTAssertTrue(model.expand(nodes[index].id), "depth \(index)")
            model.attach([nodes[index + 1]], to: nodes[index].id)
        }
        let leaf = nodes[6]
        XCTAssertEqual(model.rows.last?.node.name, "n6")
        XCTAssertEqual(model.rows.last?.depth, 6)
        XCTAssertEqual(model.rows.last?.expandable, false)
        XCTAssertFalse(model.expand(leaf.id))
        XCTAssertFalse(model.isExpanded(leaf.id))
    }

    func testCalleesAreNotExpandable() {
        var model = HierarchyModel()
        let root = node("", "main", path: "main.rs", byte: 8)
        let child = node(root.id, "record", path: "main.rs", byte: 120)
        _ = model.begin(.callees)
        model.setRoot(root, children: [child])
        XCTAssertTrue(model.rows.allSatisfy { !$0.expandable })
        XCTAssertFalse(model.expand(child.id))
    }

    func testGenerationIgnoresStaleBegin() {
        var model = HierarchyModel()
        let first = model.begin(.callers)
        let second = model.begin(.types)
        XCTAssertFalse(model.isCurrent(first))
        XCTAssertTrue(model.isCurrent(second))
        model.finishEmpty()
        XCTAssertTrue(model.finished)
        XCTAssertNil(model.root)
        XCTAssertEqual(model.childCount, 0)
    }

    private func node(_ parent: String, _ name: String, path: String, byte: UInt32) -> HierarchyNode {
        HierarchyNode(
            parent: parent,
            name: name,
            kindLabel: "fn",
            path: path,
            line: byte / 10 + 1,
            byte: byte
        )
    }

    private func chain(count: Int) -> [HierarchyNode] {
        var nodes: [HierarchyNode] = []
        var parent = ""
        for index in 0 ..< count {
            let next = node(parent, "n\(index)", path: "f.rs", byte: UInt32(index * 10))
            nodes.append(next)
            parent = next.id
        }
        return nodes
    }
}
