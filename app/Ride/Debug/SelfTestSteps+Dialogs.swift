import AppKit

extension SelfTestSteps {
    static func dialogSteps(t: TabProbe, e: SelfTestEditor) -> [SelfTestStep] {
        let disk = { (relative: String) in (try? String(contentsOf: t.url(relative), encoding: .utf8)) ?? "" }
        let cargo = disk("Cargo.toml")
        let util = disk("src/util.rs")
        return [
            SelfTestStep(name: "close dirty tab discard", run: {
                DialogScript.answers = [CloseChoice.discard]
                t.buffer("src/util.rs").map { t.state.closeBuffer($0.id) }
            }, check: {
                e.expect(t.buffer("src/util.rs") == nil && disk("src/util.rs") == util, "util open \(t.buffer("src/util.rs") != nil)")
            }),
            SelfTestStep(name: "closed dirty tab is not auto-saved", wait: 1.6, run: {
                t.state.updatePrefs { $0.autoSave = true }
                t.state.openFile(t.url("src/util.rs"))
                e.view?.insertText("// unsaved\n", replacementRange: NSRange(location: 0, length: 0))
                DialogScript.answers = [CloseChoice.discard]
                t.buffer("src/util.rs").map { t.state.closeBuffer($0.id) }
            }, check: {
                let kept = disk("src/util.rs") == util
                t.state.openFile(t.url("src/main.rs"))
                return e.expect(kept && t.buffer("src/util.rs") == nil, "util on disk changed \(!kept)")
            }),
            SelfTestStep(name: "close dirty tab save", wait: 0.4, run: {
                DialogScript.answers = [CloseChoice.save]
                t.buffer("Cargo.toml").map { t.state.closeBuffer($0.id) }
            }, check: {
                let saved = disk("Cargo.toml")
                try? cargo.write(to: t.url("Cargo.toml"), atomically: true, encoding: .utf8)
                t.state.openFile(t.url("src/main.rs"))
                return e.expect(t.buffer("Cargo.toml") == nil && saved == cargo + "\n", "cargo open \(t.buffer("Cargo.toml") != nil) saved \(saved == cargo + "\n")")
            }),
            showFile("show main before revert", state: t.state, e: e),
            revertStep("revert cancelled", t: t, e: e, answer: false),
            revertStep("revert confirmed", t: t, e: e, answer: true),
        ] + changedOnDiskSteps(t: t, e: e)
    }

    private static func revertStep(_ name: String, t: TabProbe, e: SelfTestEditor, answer: Bool) -> SelfTestStep {
        SelfTestStep(name: name, run: {
            t.state.updatePrefs { $0.autoSave = false }
            if !e.text.contains("mod util; ") {
                e.place(on: "mod util;", atEnd: true)
                e.type(" ")
            }
            DialogScript.answers = [answer]
            t.state.revertToSaved()
        }, check: {
            let dirty = t.state.activeBuffer?.isDirty ?? false
            let spaced = e.text.contains("mod util; ")
            if answer {
                t.state.updatePrefs { $0.autoSave = true }
            }
            return e.expect(dirty != answer && spaced != answer && DialogScript.answers.isEmpty, "dirty \(dirty) edit kept \(spaced)")
        })
    }
}
