import XCTest

final class BuildSessionStateTests: XCTestCase {
    func testFinishPublishesForItsOwnRun() {
        var state = BuildSessionState()
        state.begin(runId: 4)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.finish(runId: 4, status: .exited(0)), .publish)
        XCTAssertFalse(state.isActive)
    }

    func testFinishOfAnotherRunIsIgnored() {
        var state = BuildSessionState()
        state.begin(runId: 4)
        XCTAssertEqual(state.finish(runId: 3, status: .exited(0)), .ignore)
        XCTAssertTrue(state.accepts(runId: 4))
        XCTAssertEqual(state.finish(runId: 4, status: .exited(101)), .publish)
    }

    func testStoppedRunDiscards() {
        var state = BuildSessionState()
        state.begin(runId: 1)
        XCTAssertEqual(state.finish(runId: 1, status: .signalled(15)), .discard)
        XCTAssertFalse(state.isActive)
    }

    func testFailedRunDiscards() {
        var state = BuildSessionState()
        state.begin(runId: 2)
        XCTAssertEqual(state.finish(runId: 2, status: .failed("command not found")), .discard)
    }

    func testCancelledSessionIgnoresFinish() {
        var state = BuildSessionState()
        state.begin(runId: 7)
        state.cancel()
        XCTAssertEqual(state.finish(runId: 7, status: .exited(0)), .ignore)
    }

    func testFinishWithoutBeginIsIgnored() {
        var state = BuildSessionState()
        XCTAssertEqual(state.finish(runId: 1, status: .exited(0)), .ignore)
    }

    func testDeclinedStartLeavesPreviousSessionActive() {
        var state = BuildSessionState()
        state.begin(runId: 1)
        XCTAssertTrue(state.accepts(runId: 1))
        XCTAssertEqual(state.finish(runId: 1, status: .exited(0)), .publish)
    }

    func testLineOfPreviousRunIsDroppedAfterRestart() {
        var state = BuildSessionState()
        state.begin(runId: 1)
        XCTAssertTrue(state.accepts(runId: 1))
        state.begin(runId: 2)
        XCTAssertFalse(state.accepts(runId: 1))
        XCTAssertTrue(state.accepts(runId: 2))
    }

    func testFinishedSessionTakesNoTrailingLine() {
        var state = BuildSessionState()
        state.begin(runId: 3)
        XCTAssertEqual(state.finish(runId: 3, status: .exited(0)), .publish)
        XCTAssertFalse(state.accepts(runId: 3))
    }

    func testCancelledSessionTakesNoLine() {
        var state = BuildSessionState()
        state.begin(runId: 8)
        state.cancel()
        XCTAssertFalse(state.accepts(runId: 8))
    }

    func testDeclinedStartLeavesPendingChain() {
        var chain = RunChainState()
        chain.expect(runId: 1)
        XCTAssertTrue(chain.take(runId: 1, status: .exited(0)))
    }

    func testChainTakesOnlyItsOwnCleanRun() {
        var chain = RunChainState()
        chain.expect(runId: 5)
        XCTAssertFalse(chain.take(runId: 4, status: .exited(0)))
        XCTAssertTrue(chain.take(runId: 5, status: .exited(0)))
        XCTAssertFalse(chain.take(runId: 5, status: .exited(0)))
    }

    func testChainDropsStoppedCompile() {
        var chain = RunChainState()
        chain.expect(runId: 9)
        XCTAssertFalse(chain.take(runId: 9, status: .signalled(15)))
        XCTAssertFalse(chain.take(runId: 9, status: .exited(0)))
    }

    func testChainDropsFailedCompile() {
        var chain = RunChainState()
        chain.expect(runId: 3)
        XCTAssertFalse(chain.take(runId: 3, status: .exited(1)))
    }

    func testCancelledChainTakesNothing() {
        var chain = RunChainState()
        chain.expect(runId: 6)
        chain.cancel()
        XCTAssertFalse(chain.take(runId: 6, status: .exited(0)))
    }
}
