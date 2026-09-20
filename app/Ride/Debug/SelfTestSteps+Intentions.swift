import AppKit

extension SelfTestSteps {
    static func rustIntentions(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        underscoreSteps(e: e, scratch: scratch) + constantIntentionSteps(e: e, scratch: scratch)
    }

    private static func underscoreSteps(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "intention prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                let at = e.lineRange(9).location
                view.setSelectedRange(NSRange(location: at, length: 0))
                view.insertText("    let unused = 1;\n", replacementRange: NSRange(location: at, length: 0))
                resync(e: e)
            }, check: { e.expect(e.line(9) == "    let unused = 1;", "line 9: '\(e.line(9))'") }),
            SelfTestStep(name: "intention underscore", wait: 1.5, run: {
                e.activate()
                e.caret(line: 9, column: 11)
                EditorCommands.applyIntention(matching: "Rename to _unused")
            }, check: {
                e.expect(
                    e.line(9) == "    let _unused = 1;",
                    "line 9: '\(e.line(9))' notice \(e.state.notice ?? "nil")"
                )
            }),
            SelfTestStep(name: "intention undo", until: { e.line(9) == "    let unused = 1;" }, timeout: 10, run: { e.view?.undoManager?.undo() }, check: {
                e.expect(e.line(9) == "    let unused = 1;", "line 9: '\(e.line(9))'")
            }),
            restore(name: "intention cleanup", e: e, scratch: scratch),
        ]
    }

    private static func constantIntentionSteps(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "intention constant prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                resync(e: e)
            }, check: { e.expect(!e.text.contains("VALUE"), "VALUE present") }),
            SelfTestStep(name: "intention constant", wait: 1.5, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                let range = (view.string as NSString).range(of: "\"ride\"")
                guard range.location != NSNotFound else {
                    return
                }
                view.setSelectedRange(range)
                EditorCommands.applyIntention(matching: "Introduce Constant")
            }, check: {
                e.expect(
                    e.lines.contains("const VALUE: &str = \"ride\";"),
                    "notice \(e.state.notice ?? "nil") lines \(e.lines.filter { $0.contains("VALUE") })"
                )
            }),
            restore(name: "intention constant cleanup", e: e, scratch: scratch),
        ]
    }
}
