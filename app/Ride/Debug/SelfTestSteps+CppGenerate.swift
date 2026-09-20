import AppKit

extension SelfTestSteps {
    static func generatePrep(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "generate prep", wait: 1.5, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            e.activate()
            guard let view = e.view, let binding = view.hooks.binding?() else {
                return
            }
            scratch.saved = view.string
            let addition = "\n\nstruct GenBase {\n    int tag_;\n};\nstruct GenBox : GenBase {\n    std::string gname_;\n    int gy_;\n};\n"
            let end = (view.string as NSString).length
            view.setSelectedRange(NSRange(location: end, length: 0))
            view.insertText(addition, replacementRange: NSRange(location: end, length: 0))
            SessionService.shared.resync(document: binding.document, view: view)
        }, check: { e.expect(e.text.contains("struct GenBox"), "no GenBox") })
    }

    static func generateConstructor(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "generate constructor", wait: 1.0, run: {
            e.activate()
            e.place(on: "int gy_;")
            EditorCommands.applyGenerator(.constructor)
        }, check: {
            e.expect(
                e.text.contains("GenBox(std::string gname, int gy) : gname_(gname), gy_(gy) {}")
                    && !e.text.contains("tag_("),
                "text \(e.text.suffix(260))"
            )
        })
    }

    static func generateGetters(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "generate getters", wait: 0.8, run: {
            e.activate()
            e.place(on: "int gy_;")
            EditorCommands.applyGenerator(.getters)
        }, check: {
            e.expect(
                e.text.contains("std::string gname() const { return gname_; }"),
                "text \(e.text.suffix(260))"
            )
        })
    }

    static func generateCleanup(e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "generate cleanup", run: {
            guard let view = e.view else {
                return
            }
            let full = NSRange(location: 0, length: (view.string as NSString).length)
            view.insertText(scratch.saved, replacementRange: full)
            if let binding = view.hooks.binding?() {
                SessionService.shared.resync(document: binding.document, view: view)
            }
        }, check: { e.expect(!e.text.contains("GenBox"), "leftover") })
    }
}
