import XCTest

final class NewFilePromptTests: XCTestCase {
    func testDefaultLanguageFollowsProjectKind() {
        XCTAssertEqual(NewFilePrompt.language(for: .cargo), .rust)
        XCTAssertEqual(NewFilePrompt.language(for: .cmake), .cpp)
        XCTAssertEqual(NewFilePrompt.language(for: .make), .c)
        XCTAssertEqual(NewFilePrompt.language(for: .other), .rust)
    }

    func testUntitledNameUsesTheLanguageExtension() {
        XCTAssertEqual(NewFilePrompt.untitledName(for: .rust), "untitled.rs")
        XCTAssertEqual(NewFilePrompt.untitledName(for: .cpp), "untitled.cpp")
        XCTAssertEqual(NewFilePrompt.untitledName(for: .c), "untitled.c")
        XCTAssertEqual(NewFilePrompt.untitledName(for: .cmake), "untitled.cmake")
    }

    func testLanguageListMatchesTheSavePanel() {
        XCTAssertEqual(
            NewFilePrompt.languages,
            [.rust, .c, .cpp, .toml, .make, .cmake, .markdown]
        )
    }
}
