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

    static func buildStopped(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "build stopped", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 180, run: {
            state.runAction(.build)
            DemoLaunch.after(0.2) { state.stopRun() }
        }, check: {
            e.expect(
                state.runOutput.status == "stopped" && CheckService.shared.buildDiagnostics.isEmpty,
                "status \(state.runOutput.status ?? "nil") built \(CheckService.shared.buildDiagnostics.count)"
            )
        })
    }

    static func buildStopAndRerun(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "build stop and rerun", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            state.runAction(.build)
            scratch.staleRunId = state.runOutput.runId
            DemoLaunch.after(0.1) { state.runAction(.build) }
        }, check: {
            state.runOutput.append(staleLine, runId: scratch.staleRunId)
            return e.expect(
                state.runOutput.status == "exit 0"
                    && !state.runOutput.text.contains(staleLine)
                    && CheckService.shared.buildDiagnostics.isEmpty,
                "status \(state.runOutput.status ?? "nil") built \(CheckService.shared.buildDiagnostics.count) "
                    + "text \(state.runOutput.text.suffix(200))"
            )
        })
    }

    static let staleLine = "ride-stale-build-line"

    static let buildErrorLine = 13
    static let buildErrorSuffix = " let _ride_bad: u32 = \"x\";"

    static func buildDiagnostic(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "build diagnostic", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            scratch.buildLine = e.line(buildErrorLine)
            replaceLine(e, buildErrorLine, scratch.buildLine + buildErrorSuffix)
            state.saveAll()
            state.runAction(.build)
        }, check: {
            let built = CheckService.shared.buildDiagnostics
            return e.expect(
                built.count == 1 && built.first?.line == UInt32(buildErrorLine) && built.first?.origin == .build,
                "built \(built.map { "\($0.line):\($0.message)" }) status \(state.runOutput.status ?? "nil")"
            )
        })
    }

    static func buildDiagnosticCleared(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "build diagnostic cleared", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            replaceLine(e, buildErrorLine, scratch.buildLine)
            state.saveAll()
            state.runAction(.build)
        }, check: {
            e.expect(
                CheckService.shared.buildDiagnostics.isEmpty
                    && state.runOutput.status == "exit 0"
                    && e.line(buildErrorLine) == scratch.buildLine,
                "built \(CheckService.shared.buildDiagnostics.count) status \(state.runOutput.status ?? "nil") line \(e.line(buildErrorLine))"
            )
        })
    }

    private static func replaceLine(_ e: SelfTestEditor, _ number: Int, _ text: String) {
        let range = e.lineRange(number)
        e.view?.setSelectedRange(range)
        e.view?.insertText(text + "\n", replacementRange: range)
    }

    static func targetSelectionRestore(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "target selection restore", wait: 0.5, run: {
            state.selectTarget(state.projectModel.rows.first { $0.kind == .bin })
            guard let data = try? JSONEncoder().encode(state.captureWorkspace()),
                  let loaded = WorkspaceState.decode(data)
            else {
                return
            }
            state.projectModel.select(nil)
            state.restoreWorkspace(loaded)
        }, check: {
            let bin = state.projectModel.rows.first { $0.kind == .bin }
            return e.expect(
                bin != nil && state.projectModel.selected == bin && state.menu.selectedTarget == bin?.name,
                "selected \(state.projectModel.selected?.id ?? "nil") menu \(state.menu.selectedTarget ?? "nil")"
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
