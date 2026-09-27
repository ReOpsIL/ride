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

    func testBuildArgsReachBuildTestAndCargoRunButNotTheProgram() {
        let config = RunConfig(target: "ride-demo", buildArgs: ["--features", "x"], args: ["--fast"])
        XCTAssertEqual(plan(.build, config)?.argv, bin.build + ["--features", "x"])
        XCTAssertEqual(plan(.test, config)?.argv, tests.build + ["--features", "x"])
        XCTAssertEqual(plan(.run, config)?.argv, bin.run + ["--features", "x", "--", "--fast"])
    }

    func testProgramArgsStayOutOfBuildAndTest() {
        let config = RunConfig(target: "ride-demo", args: ["--fast"])
        XCTAssertEqual(plan(.build, config)?.argv, bin.build)
        XCTAssertEqual(plan(.test, config)?.argv, tests.build)
    }

    func testCMakeRunTakesProgramArgsOnly() {
        let config = RunConfig(target: "demo", buildArgs: ["-j4"], args: ["--fast"])
        let made = RunPlanner.plan(.run, target: cmakeBin, targets: [cmakeBin], config: config, kind: .cmake)
        XCTAssertEqual(made?.argv, ["build/Debug/demo", "--fast"])
        let build = RunPlanner.plan(.build, target: cmakeBin, targets: [cmakeBin], config: config, kind: .cmake)
        XCTAssertEqual(build?.argv, cmakeBin.build + ["-j4"])
    }

    func testCargoReleaseProfileAddsTheReleaseFlag() {
        let made = plan(.build, RunConfig(target: "ride-demo"), profile: "release")
        XCTAssertEqual(made?.argv, bin.build + ["--release"])
        XCTAssertEqual(plan(.run, RunConfig(target: "ride-demo"), profile: "release")?.argv, bin.run + ["--release"])
        XCTAssertEqual(plan(.build, RunConfig(target: "ride-demo"), profile: "debug")?.argv, bin.build)
    }

    func testSanitizersAddTheTargetTripleAndRustflags() {
        let config = RunConfig(target: "ride-demo", sanitizers: [.address])
        let made = plan(.build, config)
        XCTAssertEqual(made?.argv, bin.build + ["--target", RunConfig.hostTriple])
        XCTAssertEqual(made?.env["RUSTFLAGS"], "-Zsanitizer=address")
        XCTAssertNil(made?.prelude)
    }

    func testCargoIgnoresTheUndefinedSanitizer() {
        let made = plan(.build, RunConfig(target: "ride-demo", sanitizers: [.undefined]))
        XCTAssertEqual(made?.argv, bin.build)
        XCTAssertNil(made?.env["RUSTFLAGS"])
    }

    private let cmakeBin = RunTarget(
        name: "demo",
        kind: .bin,
        build: ["cmake", "--build", "build/Debug", "--target", "demo"],
        run: ["build/Debug/demo"],
        workingDir: "/tmp/c"
    )

    func testCMakeDefaultVariantNeedsNoConfigure() {
        let made = RunPlanner.plan(.build, target: cmakeBin, targets: [cmakeBin], config: RunConfig(target: "demo"), kind: .cmake, profile: "Debug")
        XCTAssertEqual(made?.argv, cmakeBin.build)
        XCTAssertNil(made?.prelude)
    }

    func testCMakeSanitizersConfigureTheirOwnBuildDirectory() {
        let config = RunConfig(target: "demo", sanitizers: [.address, .undefined])
        let build = RunPlanner.plan(.build, target: cmakeBin, targets: [cmakeBin], config: config, kind: .cmake, profile: "Debug")
        XCTAssertEqual(build?.argv, ["cmake", "--build", "build/Debug-address-undefined", "--target", "demo"])
        XCTAssertEqual(build?.prelude, [
            "cmake", "-S", "/tmp/c", "-B", "build/Debug-address-undefined", "-DCMAKE_BUILD_TYPE=Debug",
            "-DCMAKE_C_FLAGS=-fsanitize=address,undefined", "-DCMAKE_CXX_FLAGS=-fsanitize=address,undefined",
        ])
        let run = RunPlanner.plan(.run, target: cmakeBin, targets: [cmakeBin], config: config, kind: .cmake, profile: "Debug")
        XCTAssertEqual(run?.argv, ["build/Debug-address-undefined/demo"])
        XCTAssertNil(run?.prelude)
    }

    func testCMakeProfileSelectsItsBuildDirectory() {
        let config = RunConfig(target: "demo")
        let build = RunPlanner.plan(.build, target: cmakeBin, targets: [cmakeBin], config: config, kind: .cmake, profile: "Release")
        XCTAssertEqual(build?.argv, ["cmake", "--build", "build/Release", "--target", "demo"])
        XCTAssertEqual(build?.prelude, ["cmake", "-S", "/tmp/c", "-B", "build/Release", "-DCMAKE_BUILD_TYPE=Release"])
        let test = RunPlanner.plan(.test, target: cmakeBin, targets: [cmakeBin], config: config, kind: .cmake, profile: "Release")
        XCTAssertEqual(test?.argv, ["ctest", "--test-dir", "build/Release"])
    }
}
