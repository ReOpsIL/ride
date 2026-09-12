import XCTest

final class TestTreeTests: XCTestCase {
    private func row(_ suite: String, _ name: String, _ outcome: TestOutcome, output: String = "") -> TestRow {
        TestRow(suite: suite, name: name, outcome: outcome, output: output)
    }

    func testGroupsKeepSuiteOrder() {
        var tree = TestTree()
        tree.apply(row("util", "util::adds", .passed))
        tree.apply(row("", "main_works", .passed))
        tree.apply(row("util", "util::subs", .failed))
        let groups = tree.groups()
        XCTAssertEqual(groups.map(\.suite), ["util", ""])
        XCTAssertEqual(groups.first?.rows.map(\.name), ["util::adds", "util::subs"])
    }

    func testCountsAndFailedNames() {
        var tree = TestTree()
        tree.apply(row("util", "util::adds", .passed))
        tree.apply(row("util", "util::subs", .failed))
        tree.apply(row("util", "util::slow", .ignored))
        tree.apply(row("util", "util::open", .running))
        XCTAssertEqual(tree.passed, 1)
        XCTAssertEqual(tree.failed, 1)
        XCTAssertEqual(tree.ignored, 1)
        XCTAssertEqual(tree.running, 1)
        XCTAssertEqual(tree.failedNames, ["util::subs"])
    }

    func testResultReplacesStartedAndKeepsOutput() {
        var tree = TestTree()
        tree.apply(row("util", "util::adds", .running))
        tree.apply(row("util", "util::adds", .failed, output: "assert failed"))
        tree.apply(row("util", "util::adds", .running))
        XCTAssertEqual(tree.rows.count, 1)
        XCTAssertEqual(tree.rows.first?.outcome, .failed)
        XCTAssertEqual(tree.rows.first?.output, "assert failed")
    }

    func testFilterMatchesSuiteAndName() {
        var tree = TestTree()
        tree.apply(row("util", "util::adds", .passed))
        tree.apply(row("geo", "geo::area", .passed))
        XCTAssertEqual(tree.groups(filter: "ADD").flatMap { $0.rows.map(\.name) }, ["util::adds"])
        XCTAssertEqual(tree.groups(filter: "geo").flatMap { $0.rows.map(\.name) }, ["geo::area"])
        XCTAssertTrue(tree.groups(filter: "missing").isEmpty)
    }

    func testFilterCommandPerFramework() {
        XCTAssertEqual(
            TestFilterCommand.argv(names: ["util::adds"], framework: .cargo, base: ["cargo", "test"]),
            ["cargo", "test", "--", "--exact", "util::adds"]
        )
        XCTAssertEqual(
            TestFilterCommand.argv(names: ["Geo.Area", "Geo.Perimeter"], framework: .googleTest, base: ["./tests"]),
            ["./tests", "--gtest_filter=Geo.Area:Geo.Perimeter"]
        )
        XCTAssertEqual(
            TestFilterCommand.argv(names: ["areas add up"], framework: .catch2, base: ["./tests"]),
            ["./tests", "areas add up"]
        )
        XCTAssertEqual(
            TestFilterCommand.argv(names: ["smoke"], framework: .ctest, base: ["ctest"]),
            ["ctest", "-R", "smoke"]
        )
        XCTAssertNil(TestFilterCommand.argv(names: [], framework: .cargo, base: ["cargo", "test"]))
        XCTAssertNil(TestFilterCommand.argv(names: ["a"], framework: .cargo, base: []))
    }
}
