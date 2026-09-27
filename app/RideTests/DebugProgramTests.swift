import XCTest

final class DebugProgramTests: XCTestCase {
    private let bin = RunTarget(name: "demo", kind: .bin, run: ["cargo", "run", "--bin", "demo"], workingDir: "/w")

    private func resolve(_ target: RunTarget, _ variant: RunVariant, argv: [String]? = nil) -> DebugProgram? {
        DebugProgram.resolve(plan: RunPlan(argv: argv ?? target.run, env: [:], cwd: "/w"), target: target, variant: variant)
    }

    func testCargoDebugBinary() {
        let made = resolve(bin, RunVariant(kind: .cargo, profile: "debug", sanitizers: []), argv: bin.run + ["--", "-v"])
        XCTAssertEqual(made, DebugProgram(program: "/w/target/debug/demo", args: ["-v"]))
    }

    func testCargoReleaseAndSanitizedBinaries() {
        let release = resolve(bin, RunVariant(kind: .cargo, profile: "release", sanitizers: []))
        XCTAssertEqual(release?.program, "/w/target/release/demo")
        let asan = resolve(bin, RunVariant(kind: .cargo, profile: "debug", sanitizers: [.address]))
        XCTAssertEqual(asan?.program, "/w/target/\(RunConfig.hostTriple)/debug/demo")
    }

    func testCargoExampleBinary() {
        let example = RunTarget(name: "tour", kind: .example, run: ["cargo", "run", "--example", "tour"], workingDir: "/w")
        XCTAssertEqual(resolve(example, RunVariant(kind: .cargo, profile: "", sanitizers: []))?.program, "/w/target/debug/examples/tour")
    }

    func testOtherKindsDebugTheRunArgv() {
        let target = RunTarget(name: "demo", kind: .bin, run: ["build/Release/demo", "x"], workingDir: "/w")
        let made = resolve(target, RunVariant(kind: .cmake, profile: "Release", sanitizers: []))
        XCTAssertEqual(made, DebugProgram(program: "/w/build/Release/demo", args: ["x"]))
    }
}
