import AppKit

extension SelfTestSteps {
    static func completionKeySteps(e: SelfTestEditor, k: KeyRoutingScratch) -> [SelfTestStep] {
        [optionEscapeCompletes(e: e, k: k), escapeClosesCompletion(e: e), escapeWithNothingOpen(e: e, k: k), cheatSheetTakesOptionArrows(e: e, k: k)]
    }

    private static func placeInRecord(_ e: SelfTestEditor) {
        e.place(on: "counter.record")
        e.view.map { $0.setSelectedRange(NSRange(location: $0.selectedRange().location + 10, length: 0)) }
    }

    private static func optionEscapeCompletes(e: SelfTestEditor, k: KeyRoutingScratch) -> SelfTestStep {
        SelfTestStep(name: "option escape completes", until: { CompletionSession.shared.isVisible }, timeout: 8, run: {
            e.activate()
            placeInRecord(e)
            k.text = e.text
            SelfTestKeys.post("⌥esc", window: SelfTestKeys.mainWindow)
        }, check: {
            e.expect(CompletionSession.shared.isVisible && e.text == k.text, "visible \(CompletionSession.shared.isVisible)")
        })
    }

    private static func escapeClosesCompletion(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "escape closes completion", until: { !CompletionSession.shared.isVisible }, timeout: 3, run: {
            SelfTestKeys.post("esc", window: SelfTestKeys.mainWindow)
        }, check: {
            e.expect(!CompletionSession.shared.isVisible, "completion still visible")
        })
    }

    private static func escapeWithNothingOpen(e: SelfTestEditor, k: KeyRoutingScratch) -> SelfTestStep {
        SelfTestStep(name: "escape with nothing open", wait: 0.8, run: {
            k.windows = NSApp.windows.filter(\.isVisible).count
            SelfTestKeys.post("esc", window: SelfTestKeys.mainWindow)
        }, check: {
            let windows = NSApp.windows.filter(\.isVisible).count
            return e.expect(windows == k.windows && !CompletionSession.shared.isVisible && e.text == k.text, "windows \(k.windows) -> \(windows)")
        })
    }

    private static func cheatSheetTakesOptionArrows(e: SelfTestEditor, k: KeyRoutingScratch) -> SelfTestStep {
        SelfTestStep(name: "cheat sheet takes option arrows", until: {
            let sheet = CheatSheetController.shared
            if !k.posted, sheet.isVisible, let entry = sheet.popup.selectedEntry {
                k.entry = entry
                k.selection = e.view?.selectedRange() ?? k.selection
                k.posted = SelfTestKeys.post("⌥↓", window: SelfTestKeys.mainWindow)
            }
            return k.posted && sheet.popup.selectedEntry != k.entry
        }, timeout: 8, run: {
            k.posted = false
            k.entry = nil
            e.activate()
            placeInRecord(e)
            if let view = e.view {
                CheatSheetController.shared.toggle(view: view)
            }
        }, check: {
            let moved = CheatSheetController.shared.popup.selectedEntry != k.entry
            let kept = e.view?.selectedRange() == k.selection
            CheatSheetController.shared.close()
            return e.expect(k.posted && moved && kept, "posted \(k.posted) moved \(moved) selection kept \(kept)")
        })
    }
}
