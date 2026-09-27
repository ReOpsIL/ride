import CryptoKit
import Foundation
import XCTest

final class SingleFileRunTests: XCTestCase {
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
}
