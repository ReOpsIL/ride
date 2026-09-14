import XCTest

final class ClangTidyParseTests: XCTestCase {
    func testParsesWarningWithCheckName() {
        let text = "int main() {\n  int x;\n}\n"
        let path = "/proj/src/a.cpp"
        let output = "\(path):2:7: warning: unused variable 'x' [clang-diagnostic-unused-variable]\n"
        let diags = ClangTidyParse.diagnostics(output: output, path: path, text: text)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].level, .warning)
        XCTAssertEqual(diags[0].line, 2)
        XCTAssertEqual(diags[0].column, 7)
        XCTAssertEqual(diags[0].message, "unused variable 'x'")
        XCTAssertEqual(diags[0].code, "clang-diagnostic-unused-variable")
        XCTAssertEqual(diags[0].origin, .live)
        XCTAssertEqual(diags[0].byteStart, 19)
    }

    func testIgnoresOtherFilesAndNotes() {
        let path = "/proj/src/a.cpp"
        let output = """
        /proj/inc/b.h:1:1: warning: header issue [misc]
        \(path):3:1: note: expanded from macro
        \(path):3:1: error: bad thing [bugprone-x]
        """
        let diags = ClangTidyParse.diagnostics(output: output, path: path, text: "a\nb\nc\n")
        XCTAssertEqual(diags.map(\.message), ["bad thing"])
        XCTAssertEqual(diags[0].level, .error)
        XCTAssertEqual(diags[0].byteStart, 4)
    }
}
