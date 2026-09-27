import XCTest

final class RunVariantTests: XCTestCase {
    private let cmake = RunTarget(name: "demo", kind: .bin, build: ["cmake", "--build", "build/Debug", "--target", "demo"])

    func testBuildDirComesFromTheCMakeBuildArgv() {
        XCTAssertEqual(RunVariant.buildDir(in: [cmake]), "build/Debug")
        XCTAssertNil(RunVariant.buildDir(in: [RunTarget(name: "x", kind: .bin, build: ["cargo", "build"])]))
    }

    func testCMakeDirKeepsTheEngineDirForTheDefaultVariant() {
        let variant = RunVariant(kind: .cmake, profile: "Debug", sanitizers: [], targets: [cmake])
        XCTAssertEqual(variant.cmakeDir, "build/Debug")
        XCTAssertNil(variant.configure(source: "/r"))
        XCTAssertEqual(variant.argv(["build/Debug/demo"]), ["build/Debug/demo"])
    }

    func testEmptyProfileFallsBackToTheEngineProfile() {
        let variant = RunVariant(kind: .cmake, profile: "", sanitizers: [.thread], targets: [cmake])
        XCTAssertEqual(variant.cmakeDir, "build/Debug-thread")
        XCTAssertEqual(variant.argv(["ctest", "--test-dir", "build/Debug"]), ["ctest", "--test-dir", "build/Debug-thread"])
    }

    func testRelocationLeavesLookalikePathsAlone() {
        let variant = RunVariant(kind: .cmake, profile: "Release", sanitizers: [], targets: [cmake])
        XCTAssertEqual(variant.argv(["build/Debugger", "build/Debug/x"]), ["build/Debugger", "build/Release/x"])
    }

    func testCargoFlagsAndEnv() {
        let variant = RunVariant(kind: .cargo, profile: "release", sanitizers: [.thread])
        XCTAssertEqual(variant.argv(["cargo", "build"]), ["cargo", "build", "--release", "--target", RunConfig.hostTriple])
        XCTAssertEqual(variant.env, ["RUSTFLAGS": "-Zsanitizer=thread"])
        XCTAssertEqual(variant.cargoProfileDir, "release")
        XCTAssertEqual(variant.cargoTriple, RunConfig.hostTriple)
    }

    func testMakeIsUntouched() {
        let variant = RunVariant(kind: .make, profile: "default", sanitizers: [.address])
        XCTAssertEqual(variant.argv(["make", "all"]), ["make", "all"])
        XCTAssertEqual(variant.env, [:])
        XCTAssertNil(variant.configure(source: "/r"))
    }
}
