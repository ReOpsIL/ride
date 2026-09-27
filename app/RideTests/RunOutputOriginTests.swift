import XCTest

final class RunOutputOriginTests: XCTestCase {
    private let root = RunRequest(
        invocation: RunInvocation(argv: ["/bin/echo", "compile"]),
        session: .singleFile(baseDir: "/tmp"),
        then: .run(.plain(RunInvocation(argv: ["/bin/echo", "run"])))
    )

    private func finish(_ output: RunOutput) {
        let done = expectation(description: "finish")
        output.onFinish = { _, _ in done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    func testARootRequestIsItsOwnOrigin() {
        let output = RunOutput()
        XCTAssertFalse(output.canRerun)
        output.start(root)
        finish(output)
        XCTAssertEqual(output.origin, root)
        XCTAssertTrue(output.canRerun)
    }

    func testAChainedStepKeepsTheOrigin() {
        let output = RunOutput()
        output.start(root)
        finish(output)
        guard case let .run(step) = root.then else {
            return XCTFail("no step")
        }
        output.start(step, origin: output.origin)
        finish(output)
        XCTAssertEqual(output.lastRequest, step)
        XCTAssertEqual(output.origin, root)
    }

    func testAQueuedRestartCarriesItsOrigin() {
        let output = RunOutput()
        output.start(.plain(RunInvocation(argv: ["/bin/sleep", "30"])))
        output.stopAndStart(root)
        let done = expectation(description: "restarted")
        output.onFinish = { _, finish in
            if finish.succeeded {
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 8)
        XCTAssertEqual(output.origin, root)
        XCTAssertEqual(output.text, "compile")
    }
}
