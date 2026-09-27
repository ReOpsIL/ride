import AppKit

extension SelfTestSteps {
    static func checkMenuStep(_ name: String, _ path: String, state: AppState, e: SelfTestEditor, stash: SelfTestStash, plan: @escaping () -> CheckPlan?) -> SelfTestStep {
        let service = CheckService.shared
        return SelfTestStep(name: name, wait: 0.5, until: { !service.running }, timeout: 180, run: {
            e.activate()
            stash.probe = plan().map { "\($0)" } ?? "nil"
            stash.flag = SelfTestMenu.perform(path) && service.running
        }, check: {
            e.expect(
                stash.flag && !service.running && service.hasRun && stash.probe == plan().map { "\($0)" },
                "started \(stash.flag) running \(service.running) plan \(stash.probe) failure \(service.failure ?? "-")"
            )
        })
    }

    static func rustBuildMenu(state: AppState, e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let root = { state.activeCheckProject?.root }
        return [
            checkMenuStep("menu check cargo", "Build › Check", state: state, e: e, stash: stash) {
                root().map { CheckPlan.cargo(root: $0) }
            },
            checkMenuStep("menu check project cargo", "Build › Check Project", state: state, e: e, stash: stash) {
                root().map { CheckPlan.cargo(root: $0) }
            },
        ] + toolsSheetSteps(state: state, e: e) + askAISteps(e: e, stash: stash)
    }

    private static func sheetWindow(_ e: SelfTestEditor) -> NSWindow? {
        e.view?.window
    }

    private static func toolsSheetSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "menu install tools", wait: 0.5, until: { sheetWindow(e)?.attachedSheet != nil && !ToolsModel.shared.rows.isEmpty }, timeout: 10, run: {
                SelfTestMenu.perform("Build › Install Tools…")
            }, check: {
                e.expect(
                    state.showToolsSheet && sheetWindow(e)?.attachedSheet != nil && !ToolsModel.shared.rows.isEmpty,
                    "shown \(state.showToolsSheet) sheet \(sheetWindow(e)?.attachedSheet != nil) rows \(ToolsModel.shared.rows.count)"
                )
            }),
            SelfTestStep(name: "tools sheet escape", wait: 0.5, until: { !state.showToolsSheet && sheetWindow(e)?.attachedSheet == nil }, timeout: 5, run: {
                _ = SelfTestKey.escape.sendToSheet(of: sheetWindow(e))
            }, check: {
                e.expect(!state.showToolsSheet && sheetWindow(e)?.attachedSheet == nil, "tools sheet still open")
            }),
        ]
    }

    private static func askAISteps(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let ai = AIAssistant.shared
        let commented = MenuBlock.text.replacingOccurrences(of: "    let menu_a", with: "    // double the input\n    let menu_a")
        return [
            askStep("menu ask ai from comment", e: e, prompt: "double the input") {
                MenuBlock.reset(e, stash, block: commented)
                ai.prompt = "stale request"
                e.place(on: "let menu_a")
            },
            SelfTestStep(name: "ask ai escape", wait: 0.5, until: { !ai.showPrompt }, timeout: 5, run: {
                _ = SelfTestKey.escape.sendToSheet(of: sheetWindow(e))
            }, check: {
                e.expect(!ai.showPrompt && !ai.showPanel && sheetWindow(e)?.attachedSheet == nil, "prompt \(ai.showPrompt) panel \(ai.showPanel)")
            }),
            askStep("menu ask ai without comment", e: e, prompt: "") {
                e.place(on: MenuBlock.call)
            },
            SelfTestStep(name: "ask ai send without key", wait: 0.5, until: { ai.error != nil }, timeout: 10, run: {
                ai.prompt = "explain this"
                DemoLaunch.after(0.5) { _ = SelfTestKey.commandEnter.sendToSheet(of: sheetWindow(e)) }
            }, check: {
                e.expect(
                    !ai.showPrompt && ai.showPanel && ai.question == "explain this" && (ai.error ?? "").contains("API key saved"),
                    "prompt \(ai.showPrompt) panel \(ai.showPanel) error \(ai.error ?? "nil")"
                )
            }),
            SelfTestStep(name: "ask ai cleanup", run: {
                ai.showPanel = false
                MenuBlock.reset(e, stash)
            }, check: { e.expect(!ai.showPanel && e.lines.contains(MenuBlock.line), "panel \(ai.showPanel)") }),
        ]
    }

    private static func askStep(_ name: String, e: SelfTestEditor, prompt: String, prepare: @escaping () -> Void) -> SelfTestStep {
        let ai = AIAssistant.shared
        return SelfTestStep(name: name, wait: 0.5, until: { sheetWindow(e)?.attachedSheet != nil }, timeout: 5, run: {
            e.activate()
            prepare()
            SelfTestMenu.perform("Code › Ask AI from Comment…")
        }, check: {
            e.expect(
                ai.showPrompt && sheetWindow(e)?.attachedSheet != nil && ai.prompt == prompt,
                "prompt shown \(ai.showPrompt) text '\(ai.prompt)'"
            )
        })
    }
}
