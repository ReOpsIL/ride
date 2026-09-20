import XCTest
@testable import Ride

final class WorkspaceRootFinderTests: XCTestCase {
    private func finder(_ existing: Set<String>) -> (String) -> Bool {
        { existing.contains($0) }
    }

    func testNearestAncestorWithAManifestWins() {
        let exists = finder(["/p/Cargo.toml", "/p/crate/Cargo.toml"])
        let file = URL(fileURLWithPath: "/p/crate/src/lib.rs")
        XCTAssertEqual(WorkspaceRootFinder.root(for: file, fileExists: exists).path, "/p/crate")
    }

    func testEveryMarkerIsRecognised() {
        for marker in WorkspaceRootFinder.markers {
            let exists = finder(["/p/\(marker)"])
            let file = URL(fileURLWithPath: "/p/src/deep/main.c")
            XCTAssertEqual(WorkspaceRootFinder.root(for: file, fileExists: exists).path, "/p", marker)
        }
    }

    func testWithoutAMarkerTheFilesDirectoryIsTheRoot() {
        let file = URL(fileURLWithPath: "/tmp/notes/scratch.rs")
        XCTAssertEqual(WorkspaceRootFinder.root(for: file, fileExists: finder([])).path, "/tmp/notes")
    }

    func testMarkerBesideTheFileIsFound() {
        let exists = finder(["/p/Makefile"])
        XCTAssertEqual(WorkspaceRootFinder.root(for: URL(fileURLWithPath: "/p/main.c"), fileExists: exists).path, "/p")
    }
}
