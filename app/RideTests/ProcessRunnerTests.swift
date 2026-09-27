import XCTest

final class ProcessRunnerTests: XCTestCase {
    func testLinesAndExitCodeAreReported() {
        let result = run(["/bin/sh", "-c", "echo one; echo two; exit 3"])
        XCTAssertEqual(result.lines, ["one", "two"])
        XCTAssertEqual(result.finish, .exited(3))
    }

    func testBackgroundChildHoldingThePipeDoesNotBlockFinish() {
        let started = Date()
        let result = run(["/bin/sh", "-c", "sleep 20 & echo started"], timeout: 5)
        XCTAssertEqual(result.finish, .exited(0))
        XCTAssertEqual(result.lines, ["started"])
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testStopTerminatesTheWholeProcessGroup() {
        let runner = ProcessRunner()
        let done = expectation(description: "finish")
        var finish: RunFinish?
        runner.start(RunInvocation(argv: ["/bin/sh", "-c", "sleep 30 & sleep 30"]), runId: 1) { _, _ in
        } onFinish: { value in
            finish = value
            done.fulfill()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            runner.stop()
        }
        wait(for: [done], timeout: 6)
        XCTAssertEqual(finish, .signalled(SIGTERM))
        XCTAssertFalse(runner.isRunning)
    }

    func testMissingCommandFails() {
        let result = run(["ride-no-such-tool-\(UUID().uuidString)"])
        guard case .failed = result.finish else {
            return XCTFail("expected failure, got \(String(describing: result.finish))")
        }
    }

    func testExitStatusDecoding() {
        XCTAssertEqual(ProcessSpawn.finish(status: 0), .exited(0))
        XCTAssertEqual(ProcessSpawn.finish(status: 101 << 8), .exited(101))
        XCTAssertEqual(ProcessSpawn.finish(status: SIGKILL), .signalled(SIGKILL))
    }

    func testCaptureTimesOut() {
        let started = Date()
        let output = ProcessRun.output(URL(fileURLWithPath: "/bin/sleep"), ["20"], timeout: 0.3)
        XCTAssertEqual(output?.timedOut, true)
        XCTAssertEqual(output?.succeeded, false)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }

    func testCaptureKeepsRawOutput() {
        let output = ProcessRun.output(URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ' M a.rs\\n'"])
        XCTAssertEqual(output?.text, " M a.rs\n")
        XCTAssertEqual(output?.succeeded, true)
    }

    private func run(_ argv: [String], timeout: TimeInterval = 5) -> (lines: [String], finish: RunFinish?) {
        let runner = ProcessRunner()
        let done = expectation(description: "finish")
        var lines: [String] = []
        var finish: RunFinish?
        runner.start(RunInvocation(argv: argv), runId: 7) { runId, line in
            XCTAssertEqual(runId, 7)
            lines.append(line)
        } onFinish: { value in
            finish = value
            done.fulfill()
        }
        wait(for: [done], timeout: timeout)
        return (lines, finish)
    }
}
