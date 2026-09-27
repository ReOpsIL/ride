import AppKit

struct TabProbe {
    let state: AppState

    func url(_ relative: String) -> URL {
        (state.workspaceRoot ?? URL(fileURLWithPath: "/")).appendingPathComponent(relative)
    }

    func buffer(_ relative: String) -> BufferDocument? {
        state.buffers.first { $0.fileURL?.lastPathComponent == url(relative).lastPathComponent }
    }

    func pane(_ relative: String) -> UUID? {
        buffer(relative).flatMap { state.paneLayout.pane(showing: $0.id)?.id }
    }

    func dirty(_ relative: String) {
        guard let buffer = buffer(relative) else {
            return
        }
        state.replaceText(of: buffer, with: buffer.text + "\n")
        buffer.isDirty = true
    }
}

extension SelfTestSteps {
    static func tabSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let t = TabProbe(state: state)
        return [tabCloseOthersKeepsSplit(t: t, e: e), tabOpenInSplitFromOtherPane(t: t, e: e), tabCloseOthersStopsOnCancel(t: t, e: e)]
            + dialogSteps(t: t, e: e)
    }

    private static func tabCloseOthersKeepsSplit(t: TabProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tab close others keeps split pane", wait: 0.6, run: {
            t.state.openFile(t.url("src/util.rs"))
            t.state.openFile(t.url("Cargo.toml"))
            t.state.openFile(t.url("src/main.rs"))
            if let cargo = t.buffer("Cargo.toml") {
                t.state.openInSplit(cargo.id)
            }
            if let main = t.buffer("src/main.rs") {
                t.state.selectBuffer(main.id)
                t.state.closeOthers(keeping: main.id)
            }
        }, check: {
            e.expect(t.buffer("src/util.rs") == nil && t.buffer("Cargo.toml") != nil && t.pane("Cargo.toml") != t.pane("src/main.rs"),
                     "util \(t.buffer("src/util.rs") != nil) cargo \(t.buffer("Cargo.toml") != nil)")
        })
    }

    private static func tabOpenInSplitFromOtherPane(t: TabProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tab open in split from other pane", wait: 0.5, run: {
            if let main = t.buffer("src/main.rs") {
                t.state.selectBuffer(main.id)
            }
            if let cargo = t.buffer("Cargo.toml") {
                t.state.openInSplit(cargo.id)
            }
        }, check: {
            let together = t.pane("Cargo.toml") != nil && t.pane("Cargo.toml") == t.pane("src/main.rs")
            t.state.closeSplit()
            return e.expect(together, "cargo pane \(String(describing: t.pane("Cargo.toml"))) main pane \(String(describing: t.pane("src/main.rs")))")
        })
    }

    private static func tabCloseOthersStopsOnCancel(t: TabProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tab close others stops on cancel", wait: 0.5, run: {
            t.state.updatePrefs { $0.autoSave = false }
            t.state.openFile(t.url("src/util.rs"))
            t.dirty("src/util.rs")
            t.dirty("Cargo.toml")
            t.state.openFile(t.url("src/main.rs"))
            DialogScript.answers = [CloseChoice.cancel]
            t.state.closeOthers(keeping: t.buffer("src/main.rs")?.id)
        }, check: {
            e.expect(t.buffer("src/util.rs") != nil && t.buffer("Cargo.toml") != nil && DialogScript.answers.isEmpty,
                     "util \(t.buffer("src/util.rs") != nil) cargo \(t.buffer("Cargo.toml") != nil) unanswered \(DialogScript.answers.count)")
        })
    }
}
