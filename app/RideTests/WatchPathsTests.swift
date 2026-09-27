import XCTest

final class WatchPathsTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/w/app")

    func testSourceChangesPassThrough() {
        let batch = WatchPaths.classify(["/w/app/src/main.rs", "/w/app/Cargo.toml"], root: root)
        XCTAssertEqual(batch.sources, ["/w/app/src/main.rs", "/w/app/Cargo.toml"])
        XCTAssertFalse(batch.gitChanged)
    }

    func testBuildOutputIsIgnored() {
        let batch = WatchPaths.classify(["/w/app/target/debug/app", "/w/app/target/debug/deps/x.d"], root: root)
        XCTAssertTrue(batch.isEmpty)
    }

    func testTargetFolderItselfStillRefreshesTheTree() {
        XCTAssertEqual(WatchPaths.classify(["/w/app/target"], root: root).sources, ["/w/app/target"])
    }

    func testGitObjectsAreIgnoredButRefsRefreshStatus() {
        XCTAssertTrue(WatchPaths.classify(["/w/app/.git/objects/ab/cdef", "/w/app/.git/index.lock"], root: root).isEmpty)
        let batch = WatchPaths.classify(["/w/app/.git/refs/heads/main"], root: root)
        XCTAssertTrue(batch.gitChanged)
        XCTAssertTrue(batch.sources.isEmpty)
    }

    func testNestedTargetInsideASourceFolderIsKept() {
        XCTAssertEqual(WatchPaths.classify(["/w/app/src/target/x.rs"], root: root).sources, ["/w/app/src/target/x.rs"])
    }

    func testPathsOutsideTheRootAreTreatedAsSources() {
        XCTAssertEqual(WatchPaths.classify(["/private/w/app/src/a.rs"], root: root).sources, ["/private/w/app/src/a.rs"])
    }
}
