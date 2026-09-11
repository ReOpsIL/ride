import XCTest

final class RunPlanTests: XCTestCase {
    private let bin = RunTarget(
        name: "ride-demo",
        kind: .bin,
        build: ["cargo", "build", "-p", "ride-demo", "--bin", "ride-demo"],
        run: ["cargo", "run", "-p", "ride-demo", "--bin", "ride-demo"],
        workingDir: "/tmp/demo"
    )

    private let tests = RunTarget(
        name: "ride-demo",
        kind: .test,
        build: ["cargo", "test", "-p", "ride-demo"],
        workingDir: "/tmp/demo"
    )

    private func plan(_ action: RunAction, _ config: RunConfig, kind: RunProjectKind = .cargo, profile: String = "") -> RunPlan? {
        RunPlanner.plan(action, target: bin, targets: [bin, tests], config: config, kind: kind, profile: profile)
    }

    func testBuildUsesTheTargetBuildArgv() {
        let made = plan(.build, RunConfig(target: "ride-demo"))
        XCTAssertEqual(made?.argv, bin.build)
        XCTAssertEqual(made?.cwd, "/tmp/demo")
        XCTAssertEqual(made?.env, [:])
    }

    func testRunUsesTheTargetRunArgv() {
        XCTAssertEqual(plan(.run, RunConfig(target: "ride-demo"))?.argv, bin.run)
    }

    func testRunIsNilWithoutARunArgv() {
        let lib = RunTarget(name: "engine", kind: .lib, build: ["cargo", "build", "--lib"], workingDir: "/tmp/demo")
        let made = RunPlanner.plan(.run, target: lib, targets: [lib], config: RunConfig(target: "engine"), kind: .cargo)
        XCTAssertNil(made)
    }

    func testTestsPreferTheTestTarget() {
        XCTAssertEqual(plan(.test, RunConfig(target: "ride-demo"))?.argv, tests.build)
    }

    func testCargoTestFallsBackWithoutATestTarget() {
        let made = RunPlanner.plan(.test, target: bin, targets: [bin], config: RunConfig(target: "ride-demo"), kind: .cargo)
        XCTAssertEqual(made?.argv, ["cargo", "test"])
    }

    func testCMakeTestsUseCtestWithTheProfile() {
        let made = RunPlanner.plan(
            .test,
            target: bin,
            targets: [bin],
            config: RunConfig(target: "demo"),
            kind: .cmake,
            profile: "Debug"
        )
        XCTAssertEqual(made?.argv, ["ctest", "--test-dir", "build/Debug"])
    }

    func testMakeTestsNeedATestRule() {
        let all = RunTarget(name: "all", kind: .custom, build: ["make", "all"], workingDir: "/tmp/c")
        let rule = RunTarget(name: "test", kind: .custom, build: ["make", "test"], workingDir: "/tmp/c")
        XCTAssertNil(RunPlanner.plan(.test, target: all, targets: [all], config: RunConfig(target: "all"), kind: .make))
        let made = RunPlanner.plan(.test, target: all, targets: [all, rule], config: RunConfig(target: "all"), kind: .make)
        XCTAssertEqual(made?.argv, ["make", "test"])
    }

    func testArgsEnvAndBacktraceAreApplied() {
        let config = RunConfig(
            target: "ride-demo",
            args: ["--fast"],
            env: ["RUST_LOG": "debug"],
            workingDir: "/tmp/other",
            rustBacktrace: true
        )
        let made = plan(.run, config)
        XCTAssertEqual(made?.argv, bin.run + ["--", "--fast"])
        XCTAssertEqual(made?.env, ["RUST_LOG": "debug", "RUST_BACKTRACE": "1"])
        XCTAssertEqual(made?.cwd, "/tmp/other")
    }

    func testBuildArgsNeedNoSeparator() {
        let config = RunConfig(target: "ride-demo", args: ["--release"])
        XCTAssertEqual(plan(.build, config)?.argv, bin.build + ["--release"])
    }

    func testSanitizersAddTheTargetTripleAndRustflags() {
        let config = RunConfig(target: "ride-demo", sanitizers: [.address])
        let made = plan(.build, config)
        XCTAssertEqual(made?.argv, bin.build + ["--target", RunConfig.hostTriple])
        XCTAssertEqual(made?.env["RUSTFLAGS"], "-Zsanitizer=address")
    }

    func testCMakeBuildKeepsSanitizerFlagsOutOfTheArgv() {
        let target = RunTarget(
            name: "demo",
            kind: .bin,
            build: ["cmake", "--build", "build/Debug", "--target", "demo"],
            workingDir: "/tmp/c"
        )
        let config = RunConfig(target: "demo", sanitizers: [.address])
        let made = RunPlanner.plan(.build, target: target, targets: [target], config: config, kind: .cmake)
        XCTAssertEqual(made?.argv, target.build)
    }
}
