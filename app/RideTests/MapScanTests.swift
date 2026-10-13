import XCTest

final class MapScanTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ride-map-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testWorkspaceNestsCratesModulesAndUses() throws {
        try write("Cargo.toml", """
        [workspace]
        members = ["app", "lib"]
        """)
        try write("app/Cargo.toml", """
        [package]
        name = "app"
        version = "0.1.0"
        edition = "2021"

        [dependencies]
        lib = { path = "../lib" }
        """)
        try write("app/src/main.rs", """
        mod cli;

        fn main() {}
        """)
        try write("app/src/cli.rs", """
        pub fn launch() {}
        """)
        try write("lib/Cargo.toml", """
        [package]
        name = "lib"
        version = "0.1.0"
        edition = "2021"
        """)
        try write("lib/src/lib.rs", """
        mod parser;
        mod util;

        /// fn fake() {
        pub fn real() {}

        pub const BRACE: &str = "{ fn nope() {} }";

        mod inline {
            pub fn hidden() {}
        }
        """)
        try write("lib/src/parser.rs", """
        use crate::util::Unit;

        pub fn read() {}

        pub struct Doc {
            pub left: i32,
        }

        impl Doc {
            pub fn new() -> Self { Self { left: 0 } }
        }
        """)
        try write("lib/src/util.rs", """
        pub struct Unit;
        """)
        try write("target/debug/ignored.rs", "fn skip_me() {}\n")

        let graph = MapScan.graph(root: root)
        let app = try node(graph, "app")
        let lib = try node(graph, "lib")
        assertCardsApart(graph)
        XCTAssertLessThan(span(app, lib), MapSpread.length * 3)
        XCTAssertFalse(graph.nodes.contains { $0.title == "target" })

        let libInner = try XCTUnwrap(lib.nested)
        XCTAssertEqual(libInner.nodes.filter { $0.kind == .function }.map(\.title), ["real"])
        let parser = try node(libInner, "parser")
        let util = try node(libInner, "util")
        assertCardsApart(libInner)
        XCTAssertLessThan(span(parser, util), MapSpread.length * 3)
        let parserInner = try XCTUnwrap(parser.nested)
        XCTAssertTrue(parserInner.nodes.contains { $0.title == "read" })
        let implDoc = try XCTUnwrap(parserInner.nodes.first { $0.detail == "impl" })
        XCTAssertEqual(implDoc.nested?.nodes.map(\.title), ["new"])
        XCTAssertEqual(try node(libInner, "inline").nested?.nodes.map(\.title), ["hidden"])

        let appInner = try XCTUnwrap(app.nested)
        XCTAssertEqual(try node(appInner, "cli").nested?.nodes.map(\.title), ["launch"])
    }

    func testSwiftFileOpensOntoItsTypes() throws {
        try write("Models.swift", """
        struct RideMap {
            func open() {}
        }

        class Host {
            func run() {}
        }
        """)
        let graph = MapScan.graph(root: root)
        let file = try node(graph, "Models.swift")
        let type = try node(try XCTUnwrap(file.nested), "RideMap")
        XCTAssertEqual(type.nested?.nodes.map(\.title), ["open"])
        XCTAssertTrue(file.nested?.nodes.contains { $0.title == "Host" } == true)
    }

    func testCFileKeepsFunctionsAndStructs() throws {
        try write("main.c", """
        struct Point { int x; };

        int main(void) {
            return 0;
        }
        """)
        let graph = MapScan.graph(root: root)
        let names = try XCTUnwrap(try node(graph, "main.c").nested).nodes.map(\.title)
        XCTAssertTrue(names.contains("Point"))
        XCTAssertTrue(names.contains("main"))
    }

    func testCommentsAndStringsDoNotBecomeItems() {
        let parsed = MapSource.parse(
            """
            /// fn fake() {
            pub const BRACE: &str = "{ fn nope() {} }";
            pub fn real() {}
            const RAW: &str = r#" fn also_fake() { "#;
            """,
            keywords: MapSource.rustKeywords,
            prefixes: MapSource.rustPrefixes
        )
        XCTAssertEqual(parsed.decls.map(\.name), ["BRACE", "real", "RAW"])
        XCTAssertEqual(MapUses.heads("crate::util::Unit"), ["util"])
    }

    func testZoomKeepsThePointUnderTheCursor() {
        var viewport = MapViewport()
        let pivot = CGPoint(x: 120, y: 80)
        let before = viewport.flowPoint(at: pivot)
        viewport.zoom(by: 2, at: pivot)
        let after = viewport.flowPoint(at: pivot)
        XCTAssertEqual(before.x, after.x, accuracy: 0.001)
        XCTAssertEqual(before.y, after.y, accuracy: 0.001)
        XCTAssertEqual(viewport.zoom, 2)
    }

    func testOpenedMapUsesKamadaKawai() {
        let count = 8
        let nodes = (0..<count).map {
            MapNode(id: "n\($0)", title: "n\($0)", detail: "mod", kind: .module)
        }
        let edges = (0..<count).map {
            MapEdge(from: "n\($0)", to: "n\(($0 + 1) % count)", kind: .uses)
        }
        let raw = MapGraph(title: "ring", nodes: nodes, edges: edges)
        let laid = raw.laidOut()
        XCTAssertEqual(laid, MapArrange.kamadaKawai.apply(raw))
        assertCardsApart(laid)
        let session = MapSession()
        session.show(raw)
        XCTAssertEqual(session.arrangement, .kamadaKawai)
        XCTAssertEqual(session.graph, laid)
    }

    func testForceLayoutsKeepCardsApart() {
        let nodes = (0..<8).map {
            MapNode(id: "n\($0)", title: "n\($0)", detail: "mod", kind: .module, x: CGFloat($0), y: 0)
        }
        let edges = (0..<8).map {
            MapEdge(from: "n\($0)", to: "n\(($0 + 1) % 8)", kind: .uses)
        }
        let graph = MapGraph(title: "ring", nodes: nodes, edges: edges)
        for kind in [MapArrange.fruchtermanReingold, .kamadaKawai, .sugiyama] {
            let laid = kind.apply(graph)
            XCTAssertEqual(kind.apply(graph), laid)
            XCTAssertEqual(laid.nodes.map(\.id), graph.nodes.map(\.id))
            XCTAssertEqual(laid.edges, graph.edges)
            assertCardsApart(laid)
        }
    }

    func testOrphansSitAgainstTheMainGroup() {
        let core = 5
        let extra = 8
        var nodes: [MapNode] = (0..<core).map {
            MapNode(id: "c\($0)", title: "c\($0)", detail: "mod", kind: .module, x: CGFloat($0 * 10), y: 0)
        }
        nodes += (0..<extra).map {
            MapNode(id: "o\($0)", title: "o\($0)", detail: "mod", kind: .module, x: 0, y: 8_000 + CGFloat($0))
        }
        let edges = (0..<core).map {
            MapEdge(from: "c\($0)", to: "c\(($0 + 1) % core)", kind: .uses)
        }
        let graph = MapGraph(title: "mix", nodes: nodes, edges: edges)
        for kind in [MapArrange.fruchtermanReingold, .kamadaKawai, .sugiyama] {
            let laid = kind.apply(graph)
            assertCardsApart(laid)
            XCTAssertLessThan(span(laid.nodes[0], laid.nodes[1]), MapSpread.length * 2)
            let group = Array(laid.nodes.prefix(core))
            let nearest = laid.nodes.dropFirst(core).map { orphan in
                group.map { span(orphan, $0) }.min() ?? .greatestFiniteMagnitude
            }.max() ?? 0
            XCTAssertLessThan(nearest, MapSpread.length * 4)
        }
    }

    func testArrangeAppliesTheChosenLayout() {
        let inner = MapGraph(title: "in", nodes: [
            MapNode(id: "leaf", title: "leaf", detail: "fn", kind: .function),
        ], edges: [])
        let graph = MapGraph(title: "pair", nodes: [
            MapNode(id: "a", title: "a", detail: "mod", kind: .module, nested: inner),
            MapNode(id: "b", title: "b", detail: "mod", kind: .module),
        ], edges: [
            MapEdge(from: "a", to: "b", kind: .depends),
        ])
        let session = MapSession()
        session.show(graph)
        let expected = MapArrange.fruchtermanReingold.apply(session.graph)
        session.arrange(.fruchtermanReingold)
        XCTAssertEqual(session.arrangement, .fruchtermanReingold)
        XCTAssertEqual(session.layoutNonce, 1)
        XCTAssertEqual(session.graph, expected)
        XCTAssertEqual(session.graph.node("a")?.nested, inner.laidOut())
    }

    func testSugiyamaStacksADependencyDiamond() throws {
        let nodes = ["a", "b", "c", "d"].map {
            MapNode(id: $0, title: $0, detail: "mod", kind: .module)
        }
        let edges = [
            MapEdge(from: "a", to: "b", kind: .depends),
            MapEdge(from: "a", to: "c", kind: .depends),
            MapEdge(from: "b", to: "d", kind: .depends),
            MapEdge(from: "c", to: "d", kind: .depends),
        ]
        let graph = MapGraph(title: "diamond", nodes: nodes, edges: edges)
        let session = MapSession()
        session.show(graph)
        session.arrange(.sugiyama)
        XCTAssertEqual(session.arrangement, .sugiyama)
        let laid = session.graph
        XCTAssertEqual(MapArrange.sugiyama.apply(graph), laid)
        assertCardsApart(laid)
        let top = try node(laid, "a")
        let left = try node(laid, "b")
        let right = try node(laid, "c")
        let bottom = try node(laid, "d")
        XCTAssertLessThan(top.y, left.y)
        XCTAssertLessThan(top.y, right.y)
        XCTAssertEqual(left.y, right.y, accuracy: 0.5)
        XCTAssertLessThan(left.y, bottom.y)
        XCTAssertGreaterThan(abs(left.x - right.x), MapMetrics.nodeSize.width)
    }

    func testSugiyamaOrdersLayersToCutCrossings() throws {
        let nodes = ["r", "a", "b", "c", "d"].map {
            MapNode(id: $0, title: $0, detail: "mod", kind: .module)
        }
        let edges = [
            MapEdge(from: "r", to: "a", kind: .depends),
            MapEdge(from: "r", to: "b", kind: .depends),
            MapEdge(from: "a", to: "d", kind: .depends),
            MapEdge(from: "b", to: "c", kind: .depends),
        ]
        let laid = MapArrange.sugiyama.apply(MapGraph(title: "cross", nodes: nodes, edges: edges))
        assertCardsApart(laid)
        let root = try node(laid, "r")
        let sourceA = try node(laid, "a")
        let sourceB = try node(laid, "b")
        let targetC = try node(laid, "c")
        let targetD = try node(laid, "d")
        XCTAssertLessThan(root.y, sourceA.y)
        XCTAssertEqual(sourceA.y, sourceB.y, accuracy: 0.5)
        XCTAssertEqual(targetC.y, targetD.y, accuracy: 0.5)
        XCTAssertLessThan(sourceA.y, targetC.y)
        if sourceA.x <= sourceB.x {
            XCTAssertLessThanOrEqual(targetD.x, targetC.x)
        } else {
            XCTAssertLessThanOrEqual(targetC.x, targetD.x)
        }
    }

    func testShiftClickBuildsAGroupAndDragMovesIt() throws {
        let nodes = (0..<3).map {
            MapNode(id: "n\($0)", title: "n\($0)", detail: "mod", kind: .module)
        }
        let session = MapSession()
        session.show(MapGraph(title: "group", nodes: nodes, edges: []))
        session.select("n0", adding: false)
        session.select("n1", adding: true)
        XCTAssertEqual(session.selectedIDs, ["n0", "n1"])
        session.select("n0", adding: true)
        XCTAssertEqual(session.selectedIDs, ["n1"])
        session.select("n0", adding: true)
        let before = session.graph.nodes
        session.beginDrag("n0", adding: false)
        XCTAssertEqual(session.selectedIDs, ["n0", "n1"])
        session.updateDrag(CGSize(width: 30, height: 16), zoom: 2)
        session.updateDrag(CGSize(width: 30, height: 16), zoom: 2)
        let after = session.graph.nodes
        for id in ["n0", "n1"] {
            let start = try XCTUnwrap(before.first { $0.id == id })
            let end = try XCTUnwrap(after.first { $0.id == id })
            XCTAssertEqual(end.x, start.x + 15, accuracy: 0.001)
            XCTAssertEqual(end.y, start.y + 8, accuracy: 0.001)
        }
        let stay = try XCTUnwrap(after.first { $0.id == "n2" })
        let origin = try XCTUnwrap(before.first { $0.id == "n2" })
        XCTAssertEqual(stay.x, origin.x)
        XCTAssertEqual(stay.y, origin.y)
        session.endDrag()
    }

    func testDragOnAnUnselectedCardMovesOnlyThatCard() throws {
        let nodes = (0..<2).map {
            MapNode(id: "n\($0)", title: "n\($0)", detail: "mod", kind: .module)
        }
        let session = MapSession()
        session.show(MapGraph(title: "one", nodes: nodes, edges: []))
        session.select("n0", adding: false)
        let before = session.graph.nodes
        session.beginDrag("n1", adding: false)
        XCTAssertEqual(session.selectedIDs, ["n1"])
        session.updateDrag(CGSize(width: 12, height: -6), zoom: 1)
        let moved = try XCTUnwrap(session.graph.nodes.first { $0.id == "n1" })
        let start = try XCTUnwrap(before.first { $0.id == "n1" })
        XCTAssertEqual(moved.x, start.x + 12, accuracy: 0.001)
        XCTAssertEqual(moved.y, start.y - 6, accuracy: 0.001)
        let held = try XCTUnwrap(session.graph.nodes.first { $0.id == "n0" })
        let heldStart = try XCTUnwrap(before.first { $0.id == "n0" })
        XCTAssertEqual(held.x, heldStart.x)
        XCTAssertEqual(held.y, heldStart.y)
    }

    func testEnterAndBackWalkTheStack() {
        let inner = MapGraph(title: "inside", nodes: [
            MapNode(id: "leaf", title: "leaf", detail: "fn", kind: .function),
        ], edges: [])
        let outer = MapGraph(title: "outside", nodes: [
            MapNode(id: "box", title: "box", detail: "mod", kind: .module, nested: inner),
        ], edges: [])
        let session = MapSession()
        session.show(outer)
        session.enter("box")
        XCTAssertEqual(session.crumbs, ["outside", "inside"])
        session.back(to: 0)
        XCTAssertEqual(session.crumbs, ["outside"])
        session.enter("missing")
        XCTAssertEqual(session.stack.count, 1)
    }

    private func span(_ a: MapNode, _ b: MapNode) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func assertCardsApart(
        _ graph: MapGraph,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let size = MapMetrics.nodeSize
        for i in graph.nodes.indices {
            let left = graph.nodes[i]
            XCTAssertTrue(left.x.isFinite && left.y.isFinite, file: file, line: line)
            for j in graph.nodes.indices where j > i {
                let right = graph.nodes[j]
                let overlapX = size.width - abs(left.x - right.x)
                let overlapY = size.height - abs(left.y - right.y)
                XCTAssertFalse(overlapX > 0.5 && overlapY > 0.5, file: file, line: line)
            }
        }
    }

    private func node(_ graph: MapGraph, _ title: String) throws -> MapNode {
        try XCTUnwrap(graph.nodes.first { $0.title == title })
    }

    private func write(_ path: String, _ text: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
