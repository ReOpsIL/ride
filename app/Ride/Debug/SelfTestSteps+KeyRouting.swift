import AppKit

final class KeyRoutingScratch {
    let probe = SelfTestKeyProbe()
    var expected: [KeyCombo] = []
    var text = ""
    var posted = false
    var entry: CheatItem?
    var selection = NSRange(location: 0, length: 0)
    var windows = 0
}

extension SelfTestSteps {
    static func keyRoutingSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let k = KeyRoutingScratch()
        return [passToOtherResponders(e: e, k: k), reachTextField(state: state, e: e, k: k), stillRunInEditor(e: e)]
            + completionKeySteps(e: e, k: k)
    }

    private static func passToOtherResponders(e: SelfTestEditor, k: KeyRoutingScratch) -> SelfTestStep {
        SelfTestStep(name: "editor keys pass to other responders", until: {
            k.probe.received.count >= k.expected.count
        }, timeout: 5, run: {
            k.text = e.text
            k.expected = Shortcuts.editorScoped.sorted { $0.description < $1.description }
            guard k.probe.attach(to: SelfTestKeys.mainWindow) else {
                k.expected = []
                return
            }
            for combo in k.expected {
                SelfTestKeys.post(combo.description, window: SelfTestKeys.mainWindow)
            }
        }, check: {
            let missing = k.expected.filter { !k.probe.received.contains($0) }.map(\.description)
            let count = k.expected.count
            k.probe.detach()
            e.focus()
            return e.expect(count > 20 && missing.isEmpty && e.text == k.text, "sent \(count) missing \(missing) text changed \(e.text != k.text)")
        })
    }

    private static func reachTextField(state: AppState, e: SelfTestEditor, k: KeyRoutingScratch) -> SelfTestStep {
        SelfTestStep(name: "editor keys reach text field", until: {
            let responder = SelfTestKeys.mainWindow?.firstResponder
            if !k.posted, responder is NSTextView, !(responder is RideTextView) {
                k.posted = SelfTestKeys.post("⌘⌫", window: SelfTestKeys.mainWindow)
            }
            return k.posted && state.findQuery.isEmpty
        }, timeout: 5, run: {
            k.text = e.text
            k.posted = false
            e.activate()
            state.findQuery = "ride probe"
            state.showFind = true
        }, check: {
            let query = state.findQuery
            state.showFind = false
            e.focus()
            return e.expect(k.posted && query.isEmpty && e.text == k.text, "posted \(k.posted) query '\(query)' text changed \(e.text != k.text)")
        })
    }

    private static func stillRunInEditor(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "editor keys still run commands", until: { e.selectedText == "counter" }, timeout: 3, run: {
            e.activate()
            e.place(on: "counter.record")
            e.view.map { $0.setSelectedRange(NSRange(location: $0.selectedRange().location + 2, length: 0)) }
            SelfTestKeys.post("⌃W", window: SelfTestKeys.mainWindow)
        }, check: {
            e.expect(e.selectedText == "counter", "selected '\(e.selectedText)'")
        })
    }
}
