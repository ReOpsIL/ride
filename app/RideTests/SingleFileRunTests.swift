import CryptoKit
import Foundation
import XCTest

final class SingleFileRunTests: XCTestCase {
    private let follow = RunInvocation(argv: ["/tmp/out"], workingDir: "/tmp")

    func testSupportedExtensions() {
        XCTAssertTrue(SingleFileRun.canRun(path: "/a/b/main.c"))
        XCTAssertTrue(SingleFileRun.canRun(path: "/a/b/main.cpp"))
        XCTAssertTrue(SingleFileRun.canRun(path: "/a/b/main.cc"))
        XCTAssertTrue(SingleFileRun.canRun(path: "/a/b/main.cxx"))
        XCTAssertTrue(SingleFileRun.canRun(path: "/a/b/main.rs"))
    }

    func testUnsupportedExtensions() {
        XCTAssertFalse(SingleFileRun.canRun(path: "/a/b/notes.txt"))
        XCTAssertFalse(SingleFileRun.canRun(path: "/a/b/shapes.hpp"))
        XCTAssertFalse(SingleFileRun.canRun(path: "/a/b/Makefile"))
        XCTAssertFalse(SingleFileRun.canRun(path: nil))
    }

    func testOutputNameIsTheHashedPath() {
        let path = "/Users/demo/src/main.cpp"
        let digest = SHA256.hash(data: Data(path.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(SingleFileRun.outputName(for: path), "single/" + hex)
        XCTAssertEqual(hex.count, 64)
    }

    func testOutputNameDiffersPerPath() {
        XCTAssertNotEqual(
            SingleFileRun.outputName(for: "/a/main.cpp"),
            SingleFileRun.outputName(for: "/b/main.cpp")
        )
    }

    func testChainReleasesOnCleanExit() {
        let chain = SingleFileChain()
        chain.expect(follow, after: 2)
        XCTAssertEqual(chain.take(runId: 2, status: .exited(0)), follow)
    }

    func testChainReleasesOnce() {
        let chain = SingleFileChain()
        chain.expect(follow, after: 2)
        XCTAssertNotNil(chain.take(runId: 2, status: .exited(0)))
        XCTAssertNil(chain.take(runId: 2, status: .exited(0)))
    }

    func testChainHoldsOnCompileFailure() {
        let chain = SingleFileChain()
        chain.expect(follow, after: 3)
        XCTAssertNil(chain.take(runId: 3, status: .exited(1)))
        XCTAssertNil(chain.take(runId: 3, status: .exited(0)))
    }

    func testChainClearsOnStop() {
        let chain = SingleFileChain()
        chain.expect(follow, after: 4)
        XCTAssertNil(chain.take(runId: 4, status: .signalled(15)))
        XCTAssertNil(chain.take(runId: 4, status: .exited(0)))
    }

    func testChainIgnoresAnotherRunId() {
        let chain = SingleFileChain()
        chain.expect(follow, after: 5)
        XCTAssertNil(chain.take(runId: 6, status: .exited(0)))
        XCTAssertEqual(chain.take(runId: 5, status: .exited(0)), follow)
    }

    func testCancelledChainReleasesNothing() {
        let chain = SingleFileChain()
        chain.expect(follow, after: 7)
        chain.cancel()
        XCTAssertNil(chain.take(runId: 7, status: .exited(0)))
    }

    func testChainWithoutFollowUpReleasesNothing() {
        let chain = SingleFileChain()
        chain.expect(nil, after: 8)
        XCTAssertNil(chain.take(runId: 8, status: .exited(0)))
    }
}
