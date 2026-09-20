import XCTest

final class ProjectScaffoldTests: XCTestCase {
    func testNameValidation() {
        XCTAssertNil(ProjectScaffold.validate(name: "my-app"))
        XCTAssertNil(ProjectScaffold.validate(name: "_tool2"))
        XCTAssertNotNil(ProjectScaffold.validate(name: ""))
        XCTAssertNotNil(ProjectScaffold.validate(name: "   "))
        XCTAssertNotNil(ProjectScaffold.validate(name: "2fast"))
        XCTAssertNotNil(ProjectScaffold.validate(name: "-x"))
        XCTAssertNotNil(ProjectScaffold.validate(name: "a b"))
        XCTAssertNotNil(ProjectScaffold.validate(name: "a/b"))
    }

    func testRustBinaryScaffold() {
        let scaffold = ProjectScaffold(name: "hello-rs", language: .rust, buildSystem: .cargo)
        let paths = scaffold.files.map(\.path)
        XCTAssertEqual(paths, ["Cargo.toml", "src/main.rs", ".gitignore"])
        XCTAssertEqual(scaffold.mainFile, "src/main.rs")
        let manifest = scaffold.files[0].contents
        XCTAssertTrue(manifest.contains("name = \"hello-rs\""))
        XCTAssertTrue(manifest.contains("[dependencies]"))
        XCTAssertTrue(scaffold.files[1].contents.contains("fn main()"))
    }

    func testRustLibraryScaffold() {
        let scaffold = ProjectScaffold(name: "lib", language: .rust, buildSystem: .cargo, library: true)
        XCTAssertEqual(scaffold.mainFile, "src/lib.rs")
        XCTAssertTrue(scaffold.files.contains { $0.path == "src/lib.rs" && $0.contents.contains("#[test]") })
    }

    func testCMakeScaffoldUsesTargetNameAndExportsCompileCommands() {
        let c = ProjectScaffold(name: "my-tool", language: .c, buildSystem: .cmake)
        XCTAssertEqual(c.files.map(\.path), ["CMakeLists.txt", "src/main.c", ".gitignore"])
        let lists = c.files[0].contents
        XCTAssertTrue(lists.contains("project(my_tool C)"))
        XCTAssertTrue(lists.contains("CMAKE_EXPORT_COMPILE_COMMANDS ON"))
        XCTAssertTrue(lists.contains("add_executable(my_tool src/main.c)"))
        XCTAssertTrue(c.files[1].contents.contains("#include <stdio.h>"))

        let cpp = ProjectScaffold(name: "app", language: .cpp, buildSystem: .cmake)
        XCTAssertEqual(cpp.mainFile, "src/main.cpp")
        XCTAssertTrue(cpp.files[0].contents.contains("project(app CXX)"))
        XCTAssertTrue(cpp.files[0].contents.contains("CMAKE_CXX_STANDARD 20"))
        XCTAssertTrue(cpp.files[1].contents.contains("<iostream>"))
    }

    func testMakeScaffoldRecipesUseTabs() {
        let scaffold = ProjectScaffold(name: "app", language: .cpp, buildSystem: .make)
        XCTAssertEqual(scaffold.files.map(\.path), ["Makefile", "src/main.cpp", ".gitignore"])
        let makefile = scaffold.files[0].contents
        XCTAssertTrue(makefile.contains("\n\t$(CXX) $(CXXFLAGS) -o $@ $(SRC)\n"))
        XCTAssertTrue(makefile.contains("CXXFLAGS ?= -std=c++20"))
        XCTAssertTrue(makefile.contains("TARGET := app"))
        XCTAssertTrue(makefile.contains("all: $(TARGET)"))
    }

    func testLanguagesOfferMatchingBuildSystems() {
        XCTAssertEqual(ProjectLanguage.rust.buildSystems, [.cargo])
        XCTAssertEqual(ProjectLanguage.c.buildSystems, [.cmake, .make])
        XCTAssertEqual(ProjectLanguage.cpp.buildSystems, [.cmake, .make])
    }

    func testWriteCreatesTreeAndRefusesExistingFolder() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("scaffold-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("demo")
        let scaffold = ProjectScaffold(name: "demo", language: .rust, buildSystem: .cargo)
        try scaffold.write(to: root)
        XCTAssertEqual(
            try String(contentsOf: root.appendingPathComponent("src/main.rs"), encoding: .utf8),
            scaffold.files[1].contents
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Cargo.toml").path))
        XCTAssertThrowsError(try scaffold.write(to: root)) { error in
            XCTAssertEqual(error as? ScaffoldError, .exists("demo"))
        }
    }
}
