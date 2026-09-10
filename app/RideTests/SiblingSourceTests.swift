import XCTest
@testable import Ride

final class SiblingSourceTests: XCTestCase {
    func testHeaderFindsSourceInSameDirectoryFirst() {
        let header = URL(fileURLWithPath: "/p/include/geo/shapes.hpp")
        let candidates = SiblingSource.candidates(for: header)
        XCTAssertEqual(candidates.first?.path, "/p/include/geo/shapes.c")
        XCTAssertTrue(candidates.contains { $0.path == "/p/src/geo/shapes.cpp" })
        XCTAssertNil(SiblingSource.existing(for: header) { _ in false })
        XCTAssertEqual(SiblingSource.existing(for: header) { $0.path == "/p/src/geo/shapes.cpp" }?.path, "/p/src/geo/shapes.cpp")
    }

    func testSourceFindsHeaderAndOtherFilesHaveNoSibling() {
        let source = URL(fileURLWithPath: "/p/src/main.cpp")
        XCTAssertTrue(SiblingSource.candidates(for: source).contains { $0.path == "/p/include/main.h" })
        XCTAssertTrue(SiblingSource.candidates(for: URL(fileURLWithPath: "/p/src/main.rs")).isEmpty)
    }
}
