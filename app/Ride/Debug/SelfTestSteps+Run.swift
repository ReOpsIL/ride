import AppKit

extension SelfTestSteps {
    static func runEcho(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run output", wait: 2.0, run: {
            state.runInOutput(RunInvocation(argv: ["echo", "hello"], workingDir: state.workspaceRoot?.path))
        }, check: {
            e.expect(
                state.showRunOutput && state.runOutput.text.contains("hello") && state.runOutput.status == "exit 0",
                "text '\(state.runOutput.text)' status \(state.runOutput.status ?? "nil") shown \(state.showRunOutput)"
            )
        })
    }

    static func runOutputLinks(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run output link", wait: 0.4, run: {
            state.runOutput.append("  --> src/main.rs:12:5")
            if let link = ConsoleLinks.links(in: "  --> src/main.rs:12:5").first {
                state.openConsoleLink(link)
            }
        }, check: {
            e.expect(
                state.activeBuffer?.fileURL?.lastPathComponent == "main.rs" && e.caretLine == 12,
                "file \(state.activeBuffer?.fileURL?.lastPathComponent ?? "nil") caret \(e.caretLine)"
            )
        })
    }

    static func runOutputClose(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run output close", run: {
            state.runOutput.clear()
            state.showRunOutput = false
        }, check: {
            e.expect(
                state.runOutput.lines.isEmpty && state.menu.isRunning == false,
                "lines \(state.runOutput.lines.count) running \(state.menu.isRunning)"
            )
        })
    }
}
