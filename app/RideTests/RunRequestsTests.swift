import XCTest

final class RunRequestsTests: XCTestCase {
    private let plan = RunPlan(argv: ["cmake", "--build", "build/Release"], env: ["A": "1"], cwd: "/r")

    func testPlainPlanIsOneStep() {
        let request = RunRequests.request(.build, plan: plan, kind: .cmake, root: "/r")
        XCTAssertEqual(request.invocation.argv, plan.argv)
        XCTAssertEqual(request.session, .build(kind: .cmake, baseDir: "/r"))
        XCTAssertEqual(request.then, .none)
    }

    func testPreludeRunsFirstAndChainsTheBuild() {
        var configured = plan
        configured.prelude = ["cmake", "-S", "/r", "-B", "build/Release"]
        let request = RunRequests.request(.build, plan: configured, kind: .cmake, root: "/r")
        XCTAssertEqual(request.invocation.argv, configured.prelude)
        XCTAssertEqual(request.invocation.env, ["A": "1"])
        guard case let .run(build) = request.then else {
            return XCTFail("no chained build")
        }
        XCTAssertEqual(build.invocation.argv, plan.argv)
        XCTAssertEqual(build.then, .none)
    }

    func testFollowUpIsAppendedAtTheEndOfTheChain() {
        var configured = plan
        configured.prelude = ["cmake", "-S", "/r"]
        let request = RunRequests.request(.build, plan: configured, kind: .cmake, root: "/r").followed(by: .debug)
        guard case let .run(build) = request.then else {
            return XCTFail("no chained build")
        }
        XCTAssertEqual(build.then, .debug)
    }

    func testDebugFollowUpIsTerminal() {
        let request = RunRequest.plain(RunInvocation(argv: ["x"])).followed(by: .debug)
        XCTAssertEqual(request.followed(by: .run(.plain(RunInvocation(argv: ["y"])))).then, .debug)
    }

    func testCargoBuildAsksForJsonDiagnostics() {
        let cargo = RunPlan(argv: ["cargo", "build"], env: [:], cwd: "/r")
        let request = RunRequests.request(.build, plan: cargo, kind: .cargo, root: "/r")
        XCTAssertEqual(request.invocation.argv, ["cargo", "build", BuildParse.cargoFormat])
    }
}
