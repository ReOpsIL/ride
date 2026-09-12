import XCTest

final class TestTreeTests: XCTestCase {
    private func row(_ suite: String, _ name: String, _ outcome: TestOutcome, output: String = "") -> TestRow {
        TestRow(suite: suite, name: name, outcome: outcome, output: output)
    }

    func testGroupsKeepSuiteOrder() {
        var tree = TestTree()
        tree.apply(row("util", "adds", .passed))
        tree.apply(row("", "main_works", .passed))
        tree.apply(row("util", "subs", .failed))
        let groups = tree.groups()
        XCTAssertEqual(groups.map(\.suite), ["util", ""])
        XCTAssertEqual(groups.first?.rows.map(\.name), ["adds", "subs"])
    }

    func testCountsAndFailedNames() {
        var tree = TestTree()
        tree.apply(row("util", "adds", .passed))
        tree.apply(row("util", "subs", .failed))
        tree.apply(row("util", "slow", .ignored))
        tree.apply(row("util", "open", .running))
        XCTAssertEqual(tree.passed, 1)
        XCTAssertEqual(tree.failed, 1)
        XCTAssertEqual(tree.ignored, 1)
        XCTAssertEqual(tree.running, 1)
        XCTAssertEqual(tree.failedNames(framework: .cargo), ["util::subs"])
    }

    func testFailedNamesAreQualifiedPerFramework() {
        var tree = TestTree()
        tree.apply(row("GeoSuite", "DetectsDrift", .failed))
        XCTAssertEqual(tree.failedNames(framework: .googleTest), ["GeoSuite.DetectsDrift"])
        XCTAssertEqual(tree.failedNames(framework: .catch2), ["DetectsDrift"])
        var ctest = TestTree()
        ctest.apply(row("geo", "geo.detects_drift", .failed))
        XCTAssertEqual(ctest.failedNames(framework: .ctest), ["geo.detects_drift"])
        var nested = TestTree()
        nested.apply(row("util::inner", "compares", .failed))
        XCTAssertEqual(nested.failedNames(framework: .cargo), ["util::inner::compares"])
        var unsuited = TestTree()
        unsuited.apply(row("", "main_works", .failed))
        XCTAssertEqual(unsuited.failedNames(framework: .cargo), ["main_works"])
    }

    func testQualifierLeavesAlreadyQualifiedNames() {
        var tree = TestTree()
        tree.apply(row("util", "util::adds", .failed))
        XCTAssertEqual(tree.failedNames(framework: .cargo), ["util::adds"])
    }

    func testResultReplacesStartedAndKeepsOutput() {
        var tree = TestTree()
        tree.apply(row("util", "adds", .running))
        tree.apply(row("util", "adds", .failed, output: "assert failed"))
        tree.apply(row("util", "adds", .running))
        XCTAssertEqual(tree.rows.count, 1)
        XCTAssertEqual(tree.rows.first?.outcome, .failed)
        XCTAssertEqual(tree.rows.first?.output, "assert failed")
    }

    func testFilterMatchesSuiteAndName() {
        var tree = TestTree()
        tree.apply(row("util", "adds", .passed))
        tree.apply(row("geo", "area", .passed))
        XCTAssertEqual(tree.groups(filter: "ADD").flatMap { $0.rows.map(\.name) }, ["adds"])
        XCTAssertEqual(tree.groups(filter: "geo").flatMap { $0.rows.map(\.name) }, ["area"])
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
