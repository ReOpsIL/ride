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

    static func buildTarget(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "build target", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 180, run: {
            state.runAction(.build)
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.text.contains("Finished"),
                "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(200))"
            )
        })
    }

    static func runTarget(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run target", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 120, run: {
            state.runAction(.run)
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.text.contains("ride: 1"),
                "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(200))"
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

    static func runBigOutput(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run output cap", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 60, run: {
            state.runInOutput(RunInvocation(argv: ["sh", "-c", "seq 1 7000"], workingDir: state.workspaceRoot?.path))
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.buffer.last == "7000"
                    && state.runOutput.buffer.end == 7000 && state.runOutput.buffer.first > 0,
                "status \(state.runOutput.status ?? "nil") last \(state.runOutput.buffer.last ?? "nil") "
                    + "range \(state.runOutput.buffer.first)..\(state.runOutput.buffer.end)"
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
