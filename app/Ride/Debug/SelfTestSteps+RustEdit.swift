import AppKit

extension SelfTestSteps {
    static func rustEdit(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            indentKeeps(e: e, file: file, scratch: scratch),
            unindentKeeps(e: e, file: file, scratch: scratch),
            tabInserts(e: e, file: file, scratch: scratch),
            undoOneStep(e: e, file: file, scratch: scratch),
            SelfTestStep(name: "comment line", run: { e.caret(line: 10); EditorCommands.commentLine() }, check: { e.expect(e.line(10) == "    // counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "uncomment line", run: { EditorCommands.commentLine() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "comment block", run: { e.selectLines(10, 11); EditorCommands.commentBlock() }, check: { e.expect(e.line(10) == "    " + blockOpen + " counter.record(\"ride\");" && e.line(11).hasSuffix("\"engine\"); " + blockClose), "\(e.line(10)) | \(e.line(11))") }),
            SelfTestStep(name: "uncomment block", run: { EditorCommands.commentBlock() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");" && e.line(11) == "    counter.record(\"engine\");", "\(e.line(10)) | \(e.line(11))") }),
            duplicateLine(e: e, file: file, scratch: scratch),
            deleteLine(e: e, file: file, scratch: scratch),
            SelfTestStep(name: "join lines", run: { e.caret(line: 9); EditorCommands.joinLines() }, check: { e.expect(e.line(9).contains("new(); counter.record"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "undo join", run: { e.undo() }, check: { e.expect(e.line(10).contains("ride") && !e.line(9).contains("record"), "line 9: \(e.line(9))") }),
            moveLineDown(e: e, file: file, scratch: scratch),
            moveLineUp(e: e, file: file, scratch: scratch),
            SelfTestStep(name: "new line after", run: { e.caret(line: 10, column: 3); EditorCommands.newLine(before: false) }, check: { e.expect(e.line(11) == "    " && e.caretLine == 11, "line 11: '\(e.line(11))' caret \(e.caretLine)") }),
            SelfTestStep(name: "new line before", run: { EditorCommands.deleteLines(); e.caret(line: 10, column: 6); EditorCommands.newLine(before: true) }, check: { e.expect(e.line(10) == "    " && e.line(11).contains("ride"), "line 10: '\(e.line(10))'") }),
            SelfTestStep(name: "toggle case", run: { EditorCommands.deleteLines(); e.caret(line: 10, column: 7); EditorCommands.toggleCase() }, check: { e.expect(e.line(10).contains("COUNTER.record"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "toggle case back", run: { EditorCommands.toggleCase() }, check: { e.expect(e.line(10).contains("counter.record"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "sort lines", run: { e.selectLines(10, 12); EditorCommands.sortLines() }, check: { e.expect(e.line(10).contains("engine"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "undo sort", run: { e.undo() }, check: { e.expect(e.line(10).contains("ride") && e.line(11).contains("engine"), "line 10: \(e.line(10))") }),
        ]
    }
}
