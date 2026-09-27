import AppKit

enum CodeMenuPaths {
    static let editor = [
        "Code › Comment Line", "Code › Comment Block", "Code › Indent", "Code › Unindent",
        "Code › Auto-Indent Lines", "Code › Reformat Document", "Code › Reformat Selection",
        "Code › Show Intention Actions", "Code › Ask AI from Comment…", "Code › Surround With…",
        "Code › Fold", "Code › Unfold", "Code › Fold All", "Code › Unfold All",
        "Code › Trigger Completion", "Code › Quick Documentation", "Code › Quick Definition",
        "Code › External Documentation",
    ]
    static let language = [
        "Code › Complete Statement", "Code › Introduce Constant", "Code › Inline Variable",
        "Code › Cheat Sheet", "Code › Signature Help",
    ]
    static let rustAndCpp = ["Code › Generate…", "Code › Extract Variable"]

    static func mismatches(_ paths: [String], enabled: Bool) -> [String] {
        paths.filter { SelfTestMenu.isEnabled($0) != enabled }
    }
}

extension SelfTestSteps {
    static func gateStep(_ name: String, e: SelfTestEditor, enabled: [String], disabled: [String]) -> SelfTestStep {
        let settled = { CodeMenuPaths.mismatches(enabled, enabled: true).isEmpty && CodeMenuPaths.mismatches(disabled, enabled: false).isEmpty }
        return SelfTestStep(name: name, wait: 0.3, until: settled, timeout: 5, run: {}, check: {
            let wrong = CodeMenuPaths.mismatches(enabled, enabled: true).map { "\($0) disabled" }
                + CodeMenuPaths.mismatches(disabled, enabled: false).map { "\($0) enabled" }
            return e.expect(wrong.isEmpty, wrong.joined(separator: "; "))
        })
    }

    static func rustGateSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let all = CodeMenuPaths.editor + CodeMenuPaths.language + CodeMenuPaths.rustAndCpp
        let build = ["Build › Check", "Build › Check Project", "Build › Install Tools…"]
        return [
            gateStep("code menu enabled with editor", e: e, enabled: all + build, disabled: []),
            SelfTestStep(name: "code menu without editor", wait: 0.5, until: { state.activeBuffer == nil }, timeout: 5, run: {
                state.closeAll()
            }, check: { e.expect(state.activeBuffer == nil, "an editor is still open") }),
            gateStep("code menu disabled without editor", e: e, enabled: build, disabled: all),
            SelfTestStep(name: "code menu editor reopened", wait: 0.8, run: {
                if let url = state.workspaceRoot?.appendingPathComponent("src/main.rs") {
                    state.openFile(url)
                }
                e.activate()
            }, check: { e.expect(state.activeBuffer?.fileURL?.lastPathComponent == "main.rs", "main.rs not reopened") }),
            gateStep("code menu enabled again", e: e, enabled: all, disabled: []),
        ]
    }
}
