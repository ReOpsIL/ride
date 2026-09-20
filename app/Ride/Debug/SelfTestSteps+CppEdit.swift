import AppKit

extension SelfTestSteps {
    static let completeBody = "return PI * radius_ * radius_"

    static func commentLine(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "comment line", run: {
            e.focus()
            e.place(on: "std::ostringstream out;")
            EditorCommands.commentLine()
        }, check: { e.expect(e.line(15) == "    // std::ostringstream out;", "line 15: \(e.line(15))") })
    }

    static func uncommentLine(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "uncomment line", run: { EditorCommands.commentLine() }, check: {
            e.expect(e.line(15) == "    std::ostringstream out;", "line 15: \(e.line(15))")
        })
    }

    static func engineReady(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "engine session", wait: 1.5, run: {
            e.activate()
            guard let view = e.view, let binding = view.hooks.binding?() else {
                return
            }
            SessionService.shared.resync(document: binding.document, view: view)
        }, check: {
            e.expect(e.view?.hooks.binding?()?.document.sessionId != nil, "no session")
        })
    }

    static func matchingBrace(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "matching brace", wait: 0.4, run: {
            e.activate()
            e.caret(line: 22, column: 27)
            EditorCommands.matchingBrace()
        }, check: {
            e.expect(e.line(e.caretLine).trimmingCharacters(in: .whitespaces) == "}", "caret \(e.caretLine) \(e.line(e.caretLine))")
        })
    }

    static func completeStatementPrep(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "complete statement prep", wait: 0.8, run: {
            e.activate()
            e.place(on: "return name_;", atEnd: true)
            EditorCommands.newLine(before: false)
            e.type("int x = 1")
        }, check: {
            e.expect(e.line(e.caretLine).contains("int x = 1") && !e.line(e.caretLine).contains(";"), "line '\(e.line(e.caretLine))'")
        })
    }

    static func completeStatement(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "complete statement", wait: 0.8, run: {
            e.activate()
            EditorCommands.completeStatement()
        }, check: { e.expect(e.line(e.caretLine).contains("int x = 1;"), "line '\(e.line(e.caretLine))'") })
    }

    static func completeStatementCleanup(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "complete statement cleanup", run: {
            e.activate()
            EditorCommands.deleteLines()
        }, check: { e.expect(!e.text.contains("int x = 1"), "leftover") })
    }

    static func fold(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "fold", run: {
            e.activate()
            e.place(on: completeBody)
            FoldController.shared.fold()
        }, check: { e.expect(e.view?.folds.ranges.count == 1, "folds \(e.view?.folds.ranges.count ?? -1)") })
    }

    static func unfold(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "unfold all", run: { FoldController.shared.unfoldAll() }, check: {
            e.expect(e.view?.folds.isEmpty == true, "folds remain")
        })
    }
}
