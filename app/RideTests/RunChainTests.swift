import XCTest

final class RunChainTests: XCTestCase {
    private let follow = RunFollowUp.run(.plain(RunInvocation(argv: ["/tmp/out"], workingDir: "/tmp")))

    func testReleasesOnCleanExit() {
        let chain = RunChain()
        chain.expect(follow, after: 2)
        XCTAssertEqual(chain.take(runId: 2, status: .exited(0)), follow)
    }

    func testReleasesOnce() {
        let chain = RunChain()
        chain.expect(.debug, after: 2)
        XCTAssertEqual(chain.take(runId: 2, status: .exited(0)), .debug)
        XCTAssertEqual(chain.take(runId: 2, status: .exited(0)), .none)
    }

    func testHoldsOnFailure() {
        let chain = RunChain()
        chain.expect(follow, after: 3)
        XCTAssertEqual(chain.take(runId: 3, status: .exited(1)), .none)
        XCTAssertEqual(chain.take(runId: 3, status: .exited(0)), .none)
    }

    func testClearsOnStop() {
        let chain = RunChain()
        chain.expect(follow, after: 4)
        XCTAssertEqual(chain.take(runId: 4, status: .signalled(15)), .none)
        XCTAssertEqual(chain.take(runId: 4, status: .exited(0)), .none)
    }

    func testAnotherRunIdKeepsThePendingStep() {
        let chain = RunChain()
        chain.expect(follow, after: 5)
        XCTAssertEqual(chain.take(runId: 6, status: .exited(0)), .none)
        XCTAssertEqual(chain.take(runId: 5, status: .exited(0)), follow)
    }

    func testANewRunReplacesThePendingStep() {
        let chain = RunChain()
        chain.expect(.debug, after: 7)
        chain.expect(.none, after: 8)
        XCTAssertEqual(chain.take(runId: 7, status: .exited(0)), .none)
        XCTAssertEqual(chain.take(runId: 8, status: .exited(0)), .none)
    }

    func testCancelReleasesNothing() {
        let chain = RunChain()
        chain.expect(follow, after: 9)
        chain.cancel()
        XCTAssertEqual(chain.take(runId: 9, status: .exited(0)), .none)
    }
}
