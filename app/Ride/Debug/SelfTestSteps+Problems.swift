import AppKit

extension SelfTestSteps {
    static func problemsSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let model = ProblemsPanelModel.shared
        let path = (state.workspaceRoot ?? URL(fileURLWithPath: "/")).appendingPathComponent("src/main.rs").standardizedFileURL.path
        let visible = { model.filter.visible(CheckService.shared.snapshot).filter { $0.path == path } }
        let warning = { CheckService.shared.snapshot.first { $0.path == path && $0.level == .warning } }
        return [
            SelfTestStep(name: "problems filters", run: {
                state.showProblems = true
                CheckService.shared.replaceBuild([
                    Diagnostic(path: path, byteStart: 0, byteEnd: 3, line: 1, column: 1, level: .error, message: "ride probe error", code: nil, fixes: []),
                    Diagnostic(path: path, byteStart: 4, byteEnd: 8, line: 1, column: 5, level: .warning, message: "ride probe warning", code: nil, fixes: []),
                ])
                model.filter.showErrors = false
            }, check: {
                let onlyWarnings = visible().allSatisfy { $0.level == .warning } && !visible().isEmpty
                model.filter.showErrors = true
                model.filter.showWarnings = false
                let onlyErrors = visible().allSatisfy { $0.level == .error } && !visible().isEmpty
                model.filter.showWarnings = true
                return e.expect(onlyWarnings && onlyErrors && visible().count == 2, "warnings only \(onlyWarnings) errors only \(onlyErrors) all \(visible().count)")
            }),
            SelfTestStep(name: "problems selection survives filters", wait: 0.5, run: {
                if let warning = warning() {
                    state.openDiagnostic(warning)
                }
                model.filter.showErrors = false
            }, check: {
                let kept = model.selected == warning() && warning() != nil
                model.filter.showErrors = true
                model.selected = nil
                CheckService.shared.replaceBuild([])
                state.showProblems = false
                return e.expect(kept && e.caretLine == 1, "selection kept \(kept) caret \(e.caretLine)")
            }),
        ]
    }
}
