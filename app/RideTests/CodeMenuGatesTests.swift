import XCTest

final class CodeMenuGatesTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/p")

    func testNoEditorDisablesEveryEditorCommand() {
        let gates = CodeMenuGates(language: nil, check: nil, projectCheck: nil)
        XCTAssertEqual(gates, CodeMenuGates())
    }

    func testPlainCOffersNoGeneratorsOrExtract() {
        let gates = CodeMenuGates(language: .c, check: .clangFile(root), projectCheck: nil)
        XCTAssertTrue(gates.editor && gates.refactor && gates.statement && gates.signature && gates.cheatSheet)
        XCTAssertFalse(gates.generate)
        XCTAssertFalse(gates.extract)
        XCTAssertTrue(gates.check)
        XCTAssertFalse(gates.projectCheck)
    }

    func testRustAndCppOfferEveryRefactor() {
        for language in [BufferLanguage.rust, .cpp] {
            let gates = CodeMenuGates(language: language, check: nil, projectCheck: nil)
            XCTAssertTrue(gates.generate && gates.extract && gates.refactor && gates.statement, "\(language)")
        }
    }

    func testMarkdownKeepsOnlyLanguageNeutralCommands() {
        let gates = CodeMenuGates(language: .markdown, check: nil, projectCheck: .cargo(root: root))
        XCTAssertTrue(gates.editor)
        XCTAssertFalse(gates.refactor || gates.statement || gates.signature || gates.cheatSheet || gates.generate)
        XCTAssertFalse(gates.check)
        XCTAssertTrue(gates.projectCheck)
    }
}
