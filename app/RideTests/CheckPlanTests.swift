import XCTest

final class CheckPlanTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/p")
    private let file = URL(fileURLWithPath: "/p/src/main.c")

    func testClangFilesAreCheckedOnTheirOwn() {
        let cargo = CheckProject(root: root, kind: .cargo)
        XCTAssertEqual(CheckPlan.file(language: .c, url: file, project: cargo), .clangFile(file))
        XCTAssertEqual(CheckPlan.command(language: .cpp, url: file, project: nil), .clangFile(file))
    }

    func testNonClangBufferInCargoProjectChecksTheCrate() {
        let cargo = CheckProject(root: root, kind: .cargo)
        XCTAssertEqual(CheckPlan.file(language: .markdown, url: nil, project: cargo), .cargo(root: root))
        XCTAssertEqual(CheckPlan.command(language: .rust, url: file, project: cargo), .cargo(root: root))
    }

    func testNonClangBufferInCFamilyProjectNeverRunsCargo() {
        for kind in [RunProjectKind.cmake, .make, .compileDb] {
            let project = CheckProject(root: root, kind: kind)
            XCTAssertNil(CheckPlan.file(language: .cmake, url: file, project: project), "\(kind)")
            XCTAssertEqual(CheckPlan.command(language: .toml, url: nil, project: project), .clangProject(root: root))
        }
    }

    func testProjectCheckFollowsTheBuildSystem() {
        XCTAssertEqual(CheckPlan.project(CheckProject(root: root, kind: .cargo)), .cargo(root: root))
        XCTAssertEqual(CheckPlan.project(CheckProject(root: root, kind: .cmake)), .clangProject(root: root))
        XCTAssertNil(CheckPlan.project(CheckProject(root: root, kind: .none)))
        XCTAssertNil(CheckPlan.project(nil))
    }

    func testUntitledClangBufferFallsBackToTheProject() {
        let cmake = CheckProject(root: root, kind: .cmake)
        XCTAssertNil(CheckPlan.file(language: .c, url: nil, project: cmake))
        XCTAssertEqual(CheckPlan.command(language: .c, url: nil, project: cmake), .clangProject(root: root))
        XCTAssertNil(CheckPlan.command(language: .plain, url: nil, project: nil))
    }
}
