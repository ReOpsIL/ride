import AppKit

final class TypeInMiddleScratch {
    var original = ""
    var prefs: Preferences?
    var watch: ViewportWatch?
    let probe = TypeAtEndProbe()
}

extension SelfTestSteps {
    static func typeInMiddleSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let s = TypeInMiddleScratch()
        return [typeInMiddlePrep(state: state, e: e, s: s), typeInMiddle(e: e, s: s)]
    }

    private static func labelledLine(_ e: SelfTestEditor) -> Int? {
        guard let view = e.view else {
            return nil
        }
        let found = (view.string as NSString).range(of: "impl Counter {")
        return found.location == NSNotFound ? nil : view.lineIndex().line(at: found.location)
    }

    private static func typeInMiddlePrep(state: AppState, e: SelfTestEditor, s: TypeInMiddleScratch) -> SelfTestStep {
        SelfTestStep(name: "type between labelled items prep", wait: 0.4, until: {
            guard let view = e.view, let line = labelledLine(e), line > 150 else {
                return false
            }
            if let document = state.activeBuffer, view.visionLabel(forLine: line) == nil {
                UsageCounter.refresh(document: document)
                return false
            }
            let target = (view.string as NSString).range(of: "}\n\nimpl Counter {")
            view.scrollRangeToVisible(NSRange(location: target.location + 2, length: 16))
            view.setSelectedRange(NSRange(location: target.location + 2, length: 0))
            return true
        }, timeout: 20, run: {
            e.activate()
            guard let view = e.view, view.string.contains("impl Counter {") else {
                return
            }
            s.original = view.string
            s.prefs = state.prefs
            state.updatePrefs {
                $0.softWrap = true
                $0.visibleWhitespace = true
                $0.codeVision = true
            }
            let long = "// " + String(repeating: "wrapped filler text ", count: 20) + "\n"
            let filler = (0..<150).map { $0 % 10 == 0 ? long : "// filler\n" }.joined()
            view.insertText(filler, replacementRange: NSRange(location: 0, length: 0))
        }, check: {
            e.expect(labelledLine(e).map { $0 > 150 } ?? false, "impl Counter line \(labelledLine(e) ?? 0)")
        })
    }

    private static func typeInMiddle(e: SelfTestEditor, s: TypeInMiddleScratch) -> SelfTestStep {
        let presses = 4
        let pace = 0.3
        return SelfTestStep(name: "type between labelled items", wait: Double(presses) * pace + 1.5, run: {
            e.activate()
            guard let view = e.view else {
                return
            }
            s.watch = ViewportWatch(view: view)
            for index in 0..<presses {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * pace) {
                    view.insertNewline(nil)
                    s.watch?.label = "enter \(index)"
                    s.probe.watch(view, key: index, for: pace - 0.05)
                }
            }
        }, check: {
            let failures = (s.watch?.failures ?? ["viewport watch not attached"]) + s.probe.caretFailures
            if let view = e.view, !s.original.isEmpty {
                view.insertText(s.original, replacementRange: NSRange(location: 0, length: (view.string as NSString).length))
            }
            if let prefs = s.prefs {
                e.state.updatePrefs { $0 = prefs }
            }
            return e.expect(failures.isEmpty, failures.prefix(6).joined(separator: "; ") + " (layouts \(s.watch?.layouts ?? 0))")
        })
    }
}
