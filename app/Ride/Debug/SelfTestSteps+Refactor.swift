import AppKit

extension SelfTestSteps {
    static func rustRefactor(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        constantSteps(
            e: e,
            scratch: scratch,
            needle: "\"engine\"",
            declaration: "const VALUE: &str = \"engine\";"
        )
            + inlineSteps(
                e: e,
                scratch: scratch,
                addition: "fn inline_demo() {\n    let inl = 2 + 3;\n    let inl_sum = inl + 4;\n}\n\n",
                declaration: "    let inl = 2 + 3;",
                inlined: "    let inl_sum = (2 + 3) + 4;"
            )
    }

    static func cppRefactor(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        constantSteps(
            e: e,
            scratch: scratch,
            needle: "1e-9",
            declaration: "constexpr double VALUE = 1e-9;"
        )
            + inlineSteps(
                e: e,
                scratch: scratch,
                addition: "double inline_demo() {\n    double inl = 2 + 3;\n    return inl + 4;\n}\n\n",
                declaration: "    double inl = 2 + 3;",
                inlined: "    return (2 + 3) + 4;"
            )
    }

    private static func constantSteps(
        e: SelfTestEditor,
        scratch: SelfTestScratch,
        needle: String,
        declaration: String
    ) -> [SelfTestStep] {
        [
            SelfTestStep(name: "constant prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                resync(e: e)
            }, check: {
                e.expect(e.text.contains(needle) && !e.text.contains("VALUE"), "no \(needle)")
            }),
            SelfTestStep(name: "introduce constant", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                let range = (view.string as NSString).range(of: needle)
                guard range.location != NSNotFound else {
                    return
                }
                view.setSelectedRange(range)
                EditorCommands.introduceConstant()
            }, check: {
                e.expect(
                    e.lines.contains(declaration) && e.selectedText == "VALUE",
                    "selected '\(e.selectedText)' lines \(e.lines.filter { $0.contains("VALUE") })"
                )
            }),
            SelfTestStep(name: "constant undo", until: { !e.lines.contains(declaration) }, timeout: 10, run: { e.view?.undoManager?.undo() }, check: {
                e.expect(!e.lines.contains(declaration), "declaration remains")
            }),
            restore(name: "constant cleanup", e: e, scratch: scratch),
        ]
    }

    private static func inlineSteps(
        e: SelfTestEditor,
        scratch: SelfTestScratch,
        addition: String,
        declaration: String,
        inlined: String
    ) -> [SelfTestStep] {
        [
            SelfTestStep(name: "inline prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                view.setSelectedRange(NSRange(location: 0, length: 0))
                view.insertText(addition, replacementRange: NSRange(location: 0, length: 0))
                resync(e: e)
            }, check: { e.expect(e.lines.contains(declaration), "no \(declaration)") }),
            SelfTestStep(name: "inline variable", wait: 1.0, run: {
                e.activate()
                e.place(on: "inl = 2 + 3")
                EditorCommands.inlineVariable()
            }, check: {
                e.expect(
                    e.lines.contains(inlined) && !e.lines.contains(declaration),
                    "notice \(e.state.notice ?? "nil") caret \(e.caretLine) lines \(e.lines.filter { $0.contains("inl") })"
                )
            }),
            SelfTestStep(name: "inline undo", until: { e.lines.contains(declaration) }, timeout: 10, run: { e.view?.undoManager?.undo() }, check: {
                e.expect(e.lines.contains(declaration), "declaration missing")
            }),
            restore(name: "inline cleanup", e: e, scratch: scratch),
        ]
    }

    static func restore(name: String, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: name, run: {
            guard let view = e.view else {
                return
            }
            let full = NSRange(location: 0, length: (view.string as NSString).length)
            view.insertText(scratch.saved, replacementRange: full)
            resync(e: e)
        }, check: { e.expect(e.text == scratch.saved, "not restored") })
    }

    static func resync(e: SelfTestEditor) {
        guard let view = e.view, let binding = view.hooks.binding?() else {
            return
        }
        SessionService.shared.resync(document: binding.document, view: view)
    }
}
