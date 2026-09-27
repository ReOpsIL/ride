import AppKit

extension SelfTestSteps {
    static func codeMenuAssist(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        [
            SelfTestStep(name: "menu shortcuts", run: {}, check: {
                let wanted: [(String, NSEvent.ModifierFlags)] = [
                    ("Code › Trigger Completion", [.control]),
                    ("Code › Cheat Sheet", [.control, .shift]),
                    ("Code › Quick Definition", [.option]),
                ]
                let wrong = wanted.filter { path, flags in
                    let item = SelfTestMenu.item(path)
                    return item?.keyEquivalent != " " || item?.keyEquivalentModifierMask.intersection([.control, .shift, .option, .command]) != flags
                }
                return e.expect(wrong.isEmpty, "shortcuts not on the menu: \(wrong.map(\.0))")
            }),
            SelfTestStep(name: "menu trigger completion", wait: 0.5, until: { CompletionSession.shared.isVisible }, timeout: 10, run: {
                MenuBlock.reset(e, stash)
                e.place(on: "input + 2")
                if let caret = e.view?.selectedRange().location {
                    e.view?.setSelectedRange(NSRange(location: caret + 2, length: 0))
                }
                stash.probe = ""
                SelfTestMenu.perform("Code › Trigger Completion")
            }, check: {
                stash.probe = CompletionSession.shared.popup.selectedHit?.name ?? ""
                return e.expect(CompletionSession.shared.isVisible && !stash.probe.isEmpty, "completion \(CompletionSession.shared.isVisible)")
            }),
            SelfTestStep(name: "completion arrow down", run: { SelfTestKey.down.press(e.view) }, check: {
                let now = CompletionSession.shared.popup.selectedHit?.name ?? ""
                return e.expect(CompletionSession.shared.isVisible && now != stash.probe, "selection stayed on \(now)")
            }),
            SelfTestStep(name: "completion escape", run: { SelfTestKey.escape.press(e.view) }, check: {
                e.expect(!CompletionSession.shared.isVisible, "completion still visible")
            }),
        ] + cheatSheetSteps(e: e, stash: stash)
    }

    private static func cheatSheetSteps(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let sheet = CheatSheetController.shared
        return [
            SelfTestStep(name: "menu cheat sheet", wait: 0.5, until: { sheet.isVisible && sheet.popup.selectedEntry != nil }, timeout: 10, run: {
                e.activate()
                e.place(on: "menu_a * 3")
                SelfTestMenu.perform("Code › Cheat Sheet")
            }, check: {
                stash.probe = sheet.popup.selectedEntry?.name ?? ""
                return e.expect(sheet.isVisible && sheet.pinned, "visible \(sheet.isVisible) pinned \(sheet.pinned)")
            }),
            SelfTestStep(name: "cheat sheet arrow down", run: { SelfTestKey.down.press(e.view) }, check: {
                let now = sheet.popup.selectedEntry?.name ?? ""
                return e.expect(sheet.focused && now != stash.probe, "focused \(sheet.focused) entry \(now)")
            }),
            SelfTestStep(name: "cheat sheet escape", run: { SelfTestKey.escape.press(e.view) }, check: {
                e.expect(!sheet.isVisible && !sheet.pinned, "visible \(sheet.isVisible) pinned \(sheet.pinned)")
            }),
            SelfTestStep(name: "cheat sheet enter inserts", wait: 0.5, until: { !sheet.isVisible && e.text != stash.before }, timeout: 10, run: {
                SelfTestMenu.perform("Code › Cheat Sheet")
                stash.before = e.text
                DemoLaunch.after(1.5) { SelfTestKey.enter.press(e.view) }
            }, check: {
                e.expect(!sheet.isVisible && e.text != stash.before, "visible \(sheet.isVisible) changed \(e.text != stash.before)")
            }),
            SelfTestStep(name: "cheat sheet cleanup", run: {
                _ = CompletionSession.shared.endSnippet()
                MenuBlock.reset(e, stash)
            }, check: { e.expect(e.lines.contains(MenuBlock.line), "block missing") }),
        ]
    }
}
