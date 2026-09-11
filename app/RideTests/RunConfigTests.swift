import XCTest

final class RunConfigTests: XCTestCase {
    private func roundTrip(_ config: RunConfig) throws -> RunConfig {
        let data = try JSONEncoder().encode(config)
        return try JSONDecoder().decode(RunConfig.self, from: data)
    }

    func testRoundTripsThroughJson() throws {
        let config = RunConfig(
            target: "ride-demo",
            args: ["--verbose", "1"],
            env: ["RUST_LOG": "debug"],
            workingDir: "/tmp/demo",
            rustBacktrace: true,
            sanitizers: [.address, .undefined]
        )
        XCTAssertEqual(try roundTrip(config), config)
    }

    func testMissingFieldsDecodeToDefaults() throws {
        let data = Data(#"{"target":"demo"}"#.utf8)
        let config = try JSONDecoder().decode(RunConfig.self, from: data)
        XCTAssertEqual(config.target, "demo")
        XCTAssertEqual(config.args, [])
        XCTAssertEqual(config.env, [:])
        XCTAssertNil(config.workingDir)
        XCTAssertFalse(config.rustBacktrace)
        XCTAssertEqual(config.sanitizers, [])
    }

    func testDefaultConfigHasNoArgsAndInheritsWorkingDir() {
        let config = RunConfig.default(target: "demo", workingDir: "/tmp/root")
        XCTAssertEqual(config.args, [])
        XCTAssertEqual(config.env, [:])
        XCTAssertEqual(config.workingDir, "/tmp/root")
        XCTAssertFalse(config.rustBacktrace)
        XCTAssertTrue(config.sanitizers.isEmpty)
    }

    func testConfigForTargetFallsBackToTheDefault() {
        let stored = RunConfig(target: "demo", args: ["--fast"])
        let configs = [stored]
        XCTAssertEqual(RunConfig.config(for: "demo", in: configs, workingDir: "/tmp"), stored)
        let missing = RunConfig.config(for: "other", in: configs, workingDir: "/tmp")
        XCTAssertEqual(missing, RunConfig.default(target: "other", workingDir: "/tmp"))
    }

    func testMergedReplacesTheConfigForTheSameTarget() {
        let configs = [RunConfig(target: "a"), RunConfig(target: "b")]
        let merged = RunConfig.merged(RunConfig(target: "a", args: ["x"]), into: configs)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].args, ["x"])
        let appended = RunConfig.merged(RunConfig(target: "c"), into: configs)
        XCTAssertEqual(appended.map(\.target), ["a", "b", "c"])
    }

    func testNoSanitizersYieldNoFlags() {
        let config = RunConfig(target: "demo")
        for kind in RunProjectKind.allCases {
            let flags = config.flags(for: kind)
            XCTAssertEqual(flags.env, [:])
            XCTAssertEqual(flags.args, [])
            XCTAssertFalse(config.requiresNightly(for: kind))
        }
    }

    func testCargoSanitizerFlagsUseRustflagsAndHostTriple() {
        let config = RunConfig(target: "demo", sanitizers: [.undefined, .address])
        let flags = config.flags(for: .cargo)
        XCTAssertEqual(flags.env, ["RUSTFLAGS": "-Zsanitizer=address -Zsanitizer=undefined"])
        XCTAssertEqual(flags.args, ["--target", RunConfig.hostTriple])
        XCTAssertTrue(config.requiresNightly(for: .cargo))
    }

    func testCMakeSanitizerFlagsAreConfigureArguments() {
        let config = RunConfig(target: "demo", sanitizers: [.thread])
        let flags = config.flags(for: .cmake)
        XCTAssertEqual(flags.env, [:])
        XCTAssertEqual(flags.args, ["-DCMAKE_CXX_FLAGS=-fsanitize=thread"])
        XCTAssertFalse(config.requiresNightly(for: .cmake))
    }

    func testMakeAndCompileDbTakeNoSanitizerFlags() {
        let config = RunConfig(target: "demo", sanitizers: [.address])
        for kind in [RunProjectKind.make, .compileDb, .none] {
            let flags = config.flags(for: kind)
            XCTAssertEqual(flags.env, [:])
            XCTAssertEqual(flags.args, [])
        }
    }

    func testHostTripleIsADarwinTriple() {
        XCTAssertTrue(RunConfig.hostTriple.hasSuffix("-apple-darwin"))
    }

    func testWorkspaceStateCarriesRunConfigsAndSelectedTarget() throws {
        let state = WorkspaceState(
            tabs: [],
            focusedPath: nil,
            layout: .defaults,
            runConfigs: [RunConfig(target: "demo", args: ["--fast"])],
            selectedTarget: "demo"
        )
        let data = try JSONEncoder().encode(state)
        let decoded = WorkspaceState.decode(data)
        XCTAssertEqual(decoded, state)
    }

    func testOlderWorkspaceFilesDecodeWithoutRunFields() throws {
        let old = Data(#"{"version":1,"tabs":[],"layout":{}}"#.utf8)
        let decoded = WorkspaceState.decode(old)
        XCTAssertEqual(decoded?.runConfigs, [])
        XCTAssertNil(decoded?.selectedTarget)
    }
}
