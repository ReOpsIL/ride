import XCTest

final class SurroundEditTests: XCTestCase {
    private let tokens = CommentTokens.tokens(for: .rust)
    private let comment = "/" + "* … *" + "/"

    func testInlineWrapsSelectionAndSelectsInner() {
        let text = "let s = 1;\n"
        let result = apply(template("( … )", .rust), text, NSRange(location: 8, length: 1))
        XCTAssertEqual(result.text, "let s = (1);\n")
        XCTAssertEqual(result.selected, "1")
    }

    func testBlockIndentsLinesAndSelectsPlaceholder() {
        let text = "fn f() {\n    let s = 1;\n}\n"
        let result = apply(template("if", .rust), text, NSRange(location: 17, length: 1))
        XCTAssertEqual(result.text, "fn f() {\n    if condition {\n        let s = 1;\n    }\n}\n")
        XCTAssertEqual(result.selected, "condition")
    }

    func testBlockWithoutPlaceholderSelectsTheBody() {
        let text = "    a();\n    b();\n"
        let result = apply(template("loop", .rust), text, NSRange(location: 0, length: 18))
        XCTAssertEqual(result.text, "    loop {\n        a();\n        b();\n    }\n")
        XCTAssertEqual(result.selected, "        a();\n        b();")
    }

    func testBlockOnBlankLineLeavesCaretInsideTheBody() {
        let text = "    \n"
        let result = apply(template("unsafe", .rust), text, NSRange(location: 4, length: 0))
        XCTAssertEqual(result.text, "    unsafe {\n        \n    }\n")
        XCTAssertEqual(result.edit.selection, NSRange(location: 21, length: 0))
    }

    func testPreprocessorBlockKeepsBodyIndent() {
        let text = "  x();\n"
        let result = apply(template("#if 0 … #endif", .c), text, NSRange(location: 2, length: 0))
        XCTAssertEqual(result.text, "  #if 0\n  x();\n  #endif\n")
    }

    func testTemplatesPerLanguage() {
        let rust = SurroundTemplates.all(for: .rust, tokens: tokens).map(\.title)
        XCTAssertEqual(rust, ["{ … }", "( … )", "[ … ]", "\" … \"", "if", "loop", "unsafe", "match", "Some( … )", "Ok( … )", comment])
        let c = SurroundTemplates.all(for: .c, tokens: CommentTokens.tokens(for: .c)).map(\.title)
        XCTAssertEqual(c, ["{ … }", "( … )", "[ … ]", "\" … \"", "if", "while", "#if 0 … #endif", comment])
        let toml = SurroundTemplates.all(for: .toml, tokens: CommentTokens.tokens(for: .toml)).map(\.title)
        XCTAssertEqual(toml, ["{ … }", "( … )", "[ … ]", "\" … \""])
    }

    private func template(_ title: String, _ language: BufferLanguage) -> SurroundTemplate {
        let all = SurroundTemplates.all(for: language, tokens: CommentTokens.tokens(for: language))
        return all.first { $0.title == title } ?? SurroundTemplate(title: "", open: "", close: "")
    }

    private func apply(_ template: SurroundTemplate, _ text: String, _ selection: NSRange) -> (text: String, selected: String, edit: EditResult) {
        let edit = SurroundEdit.result(template, text: text, selection: selection, unit: "    ")
        let out = NSMutableString(string: text)
        for change in edit.changes.reversed() {
            out.replaceCharacters(in: change.range, with: change.text)
        }
        return (out as String, out.substring(with: edit.selection), edit)
    }
}
