import AppKit

extension SelfTestSteps {
    static func showFile(_ name: String, relative: String = "src/main.rs", marker: String = "fn main()", state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let shown = { e.text.contains(marker) && e.view?.window?.firstResponder === e.view }
        return SelfTestStep(name: name, until: shown, timeout: 4, run: {
            let root = state.workspaceRoot ?? URL(fileURLWithPath: "/")
            state.openFile(root.appendingPathComponent(relative))
            DemoLaunch.after(0.3) { e.focus() }
        }, check: {
            e.expect(shown(), "\(relative) not shown in the focused editor")
        })
    }
}
