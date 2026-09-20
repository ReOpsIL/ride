import AppKit

extension SelfTestSteps {
    static func cppQuickDefinitionOpen(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick definition open", wait: 1.5, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            e.focus()
        }, check: { e.expect(e.text.contains("Circle::area"), "no Circle::area") })
    }

    static func cppQuickDefinition(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick definition", wait: 1.2, run: {
            e.activate()
            e.caret(line: 22, column: 14)
            state.showQuickDefinition()
        }, check: {
            let peek = EditorPanes.shared.focused?.peek
            let text = peek?.excerptText ?? ""
            let labels = peek?.labels ?? []
            return e.expect(
                peek?.isVisible == true && text.contains("Circle::area") && labels.count >= 2,
                "visible \(peek?.isVisible ?? false) labels \(labels) text \(text.prefix(160))"
            )
        })
    }

    static func runFileError(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run file error", wait: 0.8, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 120, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/main.cpp") {
                state.openFile(url)
            }
            state.runFile()
        }, check: {
            let text = state.runOutput.text
            let lower = text.lowercased()
            let linked = lower.contains("undefined symbol") || lower.contains("linker command failed")
            return e.expect(
                state.runOutput.status != "exit 0" && linked && !lower.contains("file not found"),
                "status \(state.runOutput.status ?? "nil") text \(text.suffix(400))"
            )
        })
    }

    static func headerSourceSwitch(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "header source switch", wait: 0.8, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            state.switchHeaderSource()
        }, check: {
            let path = state.activeBuffer?.fileURL?.path ?? ""
            return e.expect(path.hasSuffix("include/shapes.hpp"), "path \(path)")
        })
    }
}
