import AppKit

final class ScrolledTypingScratch {
    var original = ""
    var prefs: Preferences?
    var watch: ViewportWatch?
    var topLine = 0
}

extension SelfTestSteps {
    static func scrolledTypingSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let s = ScrolledTypingScratch()
        return [scrolledTypingPrep(state: state, e: e, s: s), scrolledTyping(e: e, s: s)]
    }

    static let scrolledProbe = "trait ProbeOp {\n    fn describe(&self) -> String;\n    fn params(&self) -> u32;\n}\n\nstruct Probe;\n\nimpl ProbeOp for Probe {\n    fn describe(&self) -> String {\n        \"probe\".to_string()\n    }\n\n    fn params(&self) -> u32 {\n        let v = 1;\n"
        + (0..<70).map { "        let a\($0) = \($0);\n" }.joined()
        + "        let target = 0;\n        v\n    }\n}\n\nfn use_probe(p: &Probe) {\n    p.describe();\n    p.params();\n    p.params();\n}\n"

    private static func scrolledTypingPrep(state: AppState, e: SelfTestEditor, s: ScrolledTypingScratch) -> SelfTestStep {
        SelfTestStep(name: "type in scrolled labelled file prep", wait: 0.4, until: {
            guard state.activeBuffer?.fileURL?.lastPathComponent == "util.rs", let view = e.view, let document = state.activeBuffer else {
                if let root = state.workspaceRoot {
                    state.openFile(root.appendingPathComponent("src/util.rs"))
                }
                return false
            }
            if view.visionLines().count < 3 {
                UsageCounter.refresh(document: document)
                return false
            }
            if s.original.isEmpty {
                s.original = view.string
                s.prefs = state.prefs
                state.updatePrefs {
                    $0.softWrap = true
                    $0.visibleWhitespace = true
                    $0.codeVision = true
                }
                view.scrollRangeToVisible(NSRange(location: 0, length: 0))
                view.layoutSubtreeIfNeeded()
                let end = (view.string as NSString).length
                view.insertText("\n" + scrolledProbe, replacementRange: NSRange(location: end, length: 0))
                return false
            }
            let target = (view.string as NSString).range(of: "let target = 0;")
            guard target.location != NSNotFound else {
                return false
            }
            view.setSelectedRange(NSRange(location: target.location + 13, length: 0))
            view.scrollRangeToVisible(view.selectedRange())
            return true
        }, timeout: 30, run: {
            e.activate()
        }, check: {
            e.expect(!s.original.isEmpty && (e.view?.visionLines().count ?? 0) >= 3, "labels \(e.view?.visionLines().count ?? 0)")
        })
    }

    private static func scrolledTyping(e: SelfTestEditor, s: ScrolledTypingScratch) -> SelfTestStep {
        let keys = Array("(1, (2, x")
        let pace = 0.3
        return SelfTestStep(name: "type in scrolled labelled file", wait: Double(keys.count) * pace + 1.5, run: {
            guard let view = e.view else {
                return
            }
            s.watch = ViewportWatch(view: view)
            s.topLine = topVisibleLine(view)
            for (i, key) in keys.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * pace) {
                    view.insertText(String(key), replacementRange: NSRange(location: NSNotFound, length: 0))
                    s.watch?.label = "key \(i)"
                }
            }
        }, check: {
            let top = e.view.map(topVisibleLine) ?? 0
            let jumped = top == s.topLine ? [] : ["top line moved \(s.topLine) -> \(top)"]
            let failures = (s.watch?.failures ?? ["viewport watch not attached"]) + jumped
            if let prefs = s.prefs {
                e.state.updatePrefs { $0 = prefs }
            }
            if let view = e.view, !s.original.isEmpty {
                view.insertText(s.original, replacementRange: NSRange(location: 0, length: (view.string as NSString).length))
            }
            return e.expect(failures.isEmpty, failures.prefix(6).joined(separator: "; ") + " (layouts \(s.watch?.layouts ?? 0))")
        })
    }

    private static func topVisibleLine(_ view: RideTextView) -> Int {
        guard let tlm = view.textLayoutManager, let storage = view.textContentStorage,
              let fragment = tlm.textLayoutFragment(for: CGPoint(x: 0, y: view.visibleRect.minY - view.textContainerOrigin.y))
        else {
            return 0
        }
        return view.lineIndex().line(at: storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location))
    }
}
