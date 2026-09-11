import XCTest

final class TargetRowsTests: XCTestCase {
    private func row(_ name: String, _ kind: TargetRowKind) -> TargetRow {
        TargetRow(name: name, kind: kind, detail: "cargo build")
    }

    func testGroupsFollowKindOrderAndSkipEmptyKinds() {
        let groups = TargetRows.grouped([
            row("unit", .test),
            row("demo", .bin),
            row("shapes", .lib),
        ])
        XCTAssertEqual(groups.map(\.kind), [.bin, .lib, .test])
        XCTAssertEqual(groups.map(\.title), ["Binaries", "Libraries", "Tests"])
    }

    func testRowsAreSortedByDisplayNameWithinAGroup() {
        let groups = TargetRows.grouped([
            row("src/zeta.c", .custom),
            row("src/alpha.c", .custom),
            row("other/beta.c", .custom),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(
            groups[0].rows.map(\.name),
            ["src/alpha.c", "other/beta.c", "src/zeta.c"]
        )
    }

    func testDisplayNameIsTheLastPathComponent() {
        XCTAssertEqual(TargetRows.displayName(row("src/main.cpp", .custom)), "main.cpp")
        XCTAssertEqual(TargetRows.displayName(row("ride-demo", .bin)), "ride-demo")
    }

    func testIdentityCombinesKindAndName() {
        XCTAssertNotEqual(row("demo", .bin).id, row("demo", .test).id)
        XCTAssertEqual(row("demo", .bin), row("demo", .bin))
    }

    func testEmptyInputHasNoGroups() {
        XCTAssertTrue(TargetRows.grouped([]).isEmpty)
    }
}
