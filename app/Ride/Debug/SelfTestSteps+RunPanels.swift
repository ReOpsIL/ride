import AppKit

extension SelfTestSteps {
    static func runPanelSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let scratch = SelfTestRunScratch()
        return [
            testsPanelRow(state: state, e: e),
            testsPanelClearHide(state: state, e: e),
            terminalTabs(state: state, e: e, scratch: scratch),
            terminalTabsClose(state: state, e: e, scratch: scratch),
            runPanelStop(state: state, e: e),
            toolbarButtons(state: state, e: e),
        ] + targetSteps(state: state, e: e, scratch: scratch)
    }

    private static func testsPanelRow(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tests panel row select", wait: 0.3, run: {
            let store = TestRunStore.shared
            store.selected = store.tree.rows.first?.id
        }, check: {
            let store = TestRunStore.shared
            let row = store.selected.flatMap { store.tree.row(id: $0) }
            return e.expect(row?.name == "counts_one" && state.showTests, "selected \(store.selected ?? "nil") shown \(state.showTests)")
        })
    }

    private static func testsPanelClearHide(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tests panel clear hide", wait: 0.3, run: {
            TestRunStore.shared.clear()
            state.showTests = false
        }, check: {
            let store = TestRunStore.shared
            return e.expect(
                store.tree.rows.isEmpty && store.status == nil && !state.showTests && !state.menu.showTests,
                "rows \(store.tree.rows.count) status \(store.status ?? "nil") shown \(state.showTests)"
            )
        })
    }

    private static func terminalTabs(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "terminal panel tabs", wait: 0.6, run: {
            scratch.tabs = state.terminals.tabs.count
            state.newTerminal()
            state.newTerminal()
            if let first = state.terminals.tabs.items.first?.id {
                state.selectTerminal(first)
            }
        }, check: {
            let tabs = state.terminals.tabs
            return e.expect(
                tabs.count == scratch.tabs + 2 && tabs.selected == tabs.items.first?.id && state.showTerminal,
                "tabs \(tabs.count) selected first \(tabs.selected == tabs.items.first?.id)"
            )
        })
    }

    private static func terminalTabsClose(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "terminal panel close hide", wait: 0.6, run: {
            if let selected = state.terminals.tabs.selected {
                state.closeTerminal(selected)
            }
            scratch.terminal = state.terminals.tabs.selected
            state.showTerminal = false
        }, check: {
            let remaining = state.terminals.tabs.items.map(\.id)
            state.terminals.closeAll()
            e.focus()
            return e.expect(
                remaining.count == 1 && scratch.terminal == remaining.first && !state.showTerminal && !state.menu.showTerminal,
                "remaining \(remaining.count) shown \(state.showTerminal)"
            )
        })
    }

    private static func runPanelStop(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run panel stop clear hide", wait: 0.5, until: { SelfTestRunScratch.finished(state) }, timeout: 30, run: {
            state.startRun(.plain(RunInvocation(argv: ["sleep", "30"], workingDir: state.workspaceRoot?.path)))
            state.stopRun()
        }, check: {
            let stopped = state.runOutput.status == "stopped"
            state.runOutput.clear()
            state.showRunOutput = false
            return e.expect(
                stopped && state.runOutput.lines.isEmpty && !state.menu.showRunOutput,
                "stopped \(stopped) lines \(state.runOutput.lines.count) shown \(state.showRunOutput)"
            )
        })
    }

    private static func toolbarButtons(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "toolbar buttons", wait: 0.4, run: {}, check: {
            let sidebar = state.showSidebar
            let problems = state.showProblems
            state.showSidebar.toggle()
            state.toggleProblems()
            state.toggleQuickOpen()
            let flipped = state.showSidebar != sidebar && state.showProblems != problems && state.showQuickOpen
            state.toggleQuickOpen()
            state.toggleProblems()
            state.showSidebar.toggle()
            e.focus()
            return e.expect(
                flipped && state.showSidebar == sidebar && state.showProblems == problems && !state.showQuickOpen,
                "flipped \(flipped) sidebar \(state.showSidebar) problems \(state.showProblems)"
            )
        })
    }
}
