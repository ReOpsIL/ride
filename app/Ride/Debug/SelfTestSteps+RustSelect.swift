import AppKit

extension SelfTestSteps {
    static func rustSelect(e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "select word", run: { e.caret(line: 10, column: 14); EditorCommands.selectWord() }, check: { e.expect(e.selectedText == "record", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "extend selection", run: { EditorCommands.extendSelection() }, check: { e.expect(e.selectedText.count > 6 && e.selectedText.contains("record"), "selected: \(e.selectedText)") }),
            SelfTestStep(name: "shrink selection", run: { EditorCommands.shrinkSelection() }, check: { e.expect(e.selectedText == "record", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "select line", run: { EditorCommands.selectLine() }, check: { e.expect(e.selectedText.hasSuffix("\n") && e.selectedText.contains("ride"), "selected: \(e.selectedText)") }),
            SelfTestStep(name: "matching brace", run: { e.caret(line: 8, column: 12); EditorCommands.matchingBrace() }, check: { e.expect(e.caretLine == 20, "caret \(e.caretLine)") }),
            SelfTestStep(name: "smart newline", run: { e.caret(line: 8, column: 12); e.view?.insertNewline(nil) }, check: { e.expect(e.line(9) == "    " && e.caretLine == 9, "line 9: '\(e.line(9))' caret \(e.caretLine)") }),
            SelfTestStep(name: "closing brace dedent", run: { e.view?.insertText("}", replacementRange: NSRange(location: NSNotFound, length: 0)) }, check: { e.expect(e.line(9) == "}", "line 9: '\(e.line(9))'") }),
            SelfTestStep(name: "cleanup brace", run: { EditorCommands.deleteLines() }, check: { e.expect(e.line(9).contains("Counter::new"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "bracket pairing", run: { e.caret(line: 10, column: 28); e.view?.insertText("(", replacementRange: NSRange(location: NSNotFound, length: 0)) }, check: { e.expect(e.line(10).hasSuffix(";()") && e.caretLine == 10, "line 10: \(e.line(10))") }),
            SelfTestStep(name: "pair backspace", run: { e.view?.deleteBackward(nil) }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
        ]
    }
}
