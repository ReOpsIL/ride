import AppKit

final class FindBarScratch {
    var counts: [String: Int] = [:]
    var posted = 0
    var first = 0
}

extension SelfTestSteps {
    static func findBarSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let f = FindBarScratch()
        return [findOptionToggles(state: state, e: e, f: f), findKeysInField(state: state, e: e, f: f), findReplaceOne(state: state, e: e),
                findCloseRefocuses(state: state, e: e), findEscapeCloses(state: state, e: e, f: f)]
    }

    private static func findCount(_ state: AppState, _ e: SelfTestEditor) -> Int {
        FindMatcher.matches(in: e.text, query: state.findQuery, options: state.findOptions).count
    }

    private static func findFieldFocused(_ e: SelfTestEditor) -> Bool {
        let responder = SelfTestKeys.mainWindow?.firstResponder
        return responder is NSTextView && !(responder is RideTextView)
    }

    private static func findOptionToggles(state: AppState, e: SelfTestEditor, f: FindBarScratch) -> SelfTestStep {
        SelfTestStep(name: "find option toggles", run: {
            state.findOptions = .defaults
            state.findQuery = "counter"
            f.counts["any case"] = findCount(state, e)
            state.findOptions.caseSensitive.toggle()
            f.counts["match case"] = findCount(state, e)
            state.findOptions.caseSensitive.toggle()
            state.findQuery = "count"
            f.counts["substring"] = findCount(state, e)
            state.findOptions.wholeWord.toggle()
            f.counts["whole word"] = findCount(state, e)
            state.findOptions.wholeWord.toggle()
            state.findQuery = "rec.rd"
            f.counts["literal"] = findCount(state, e)
            state.findOptions.regex.toggle()
            f.counts["regex"] = findCount(state, e)
            state.findOptions = .defaults
        }, check: {
            let c = f.counts
            let ok = (c["match case"] ?? 0) > 0 && (c["match case"] ?? 0) < (c["any case"] ?? 0)
                && (c["whole word"] ?? 0) > 0 && (c["whole word"] ?? 0) < (c["substring"] ?? 0)
                && c["literal"] == 0 && (c["regex"] ?? 0) > 0
            return e.expect(ok, "\(c)")
        })
    }

    private static func findKeysInField(state: AppState, e: SelfTestEditor, f: FindBarScratch) -> SelfTestStep {
        SelfTestStep(name: "find return and shift return", until: {
            guard findFieldFocused(e) else {
                return false
            }
            let location = e.view?.selectedRange().location ?? 0
            if f.posted == 0 || (f.posted == 1 && e.selectedText.isEmpty && f.first % 6 == 5) {
                f.posted = SelfTestKeys.post("↩", window: SelfTestKeys.mainWindow) ? 1 : 0
            }
            if f.posted == 1, e.selectedText.isEmpty {
                f.first += 1
            } else if f.posted == 1, e.selectedText.lowercased() == "record" {
                f.first = location
                f.posted = SelfTestKeys.post("⇧↩", window: SelfTestKeys.mainWindow) ? 2 : 1
            }
            return f.posted == 2 && e.selectedText.lowercased() == "record" && location != f.first
        }, timeout: 8, run: {
            f.posted = 0
            f.first = 0
            e.activate()
            e.place(on: "counter.record(\"engine\")")
            state.findOrigin = e.view?.selectedRange().location ?? 0
            state.findRange = nil
            state.findQuery = "record"
            state.showFind = true
        }, check: {
            let location = e.view?.selectedRange().location ?? 0
            let responder = SelfTestKeys.mainWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
            state.showFind = false
            e.focus()
            return e.expect(f.posted == 2 && e.selectedText.lowercased() == "record" && location < f.first, "posted \(f.posted) first \(f.first) now \(location) '\(e.selectedText)' responder \(responder) find \(state.showFind)")
        })
    }

    private static func findReplaceOne(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "find replace one", run: {
            state.showReplaceField = true
            state.findOptions = FindOptions(caseSensitive: true, wholeWord: false, regex: false)
            state.findQuery = "\"engine\""
            state.replaceQuery = "\"ENGINE\""
            e.caret(line: 1)
            state.findOrigin = 0
            state.findRange = nil
            state.replaceOne()
        }, check: {
            let replaced = e.text.components(separatedBy: "\"ENGINE\"").count - 1
            let left = e.text.components(separatedBy: "\"engine\"").count - 1
            if let view = e.view {
                let range = (view.string as NSString).range(of: "\"ENGINE\"")
                if range.location != NSNotFound {
                    view.replaceText(in: range, with: "\"engine\"")
                }
            }
            let restored = e.text.components(separatedBy: "\"ENGINE\"").count - 1
            state.findOptions = .defaults
            state.showReplaceField = false
            return e.expect(replaced == 1 && left > 0 && restored == 0, "replaced \(replaced) left \(left) after undo \(restored)")
        })
    }

    private static func findCloseRefocuses(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "find close refocuses editor", until: { !state.showFind && e.view?.window?.firstResponder === e.view }, timeout: 3, run: {
            state.showFind = true
            DemoLaunch.after(0.4) { state.closeFind() }
        }, check: {
            e.expect(!state.showFind && e.view?.window?.firstResponder === e.view, "find \(state.showFind) responder \(String(describing: e.view?.window?.firstResponder))")
        })
    }

    private static func findEscapeCloses(state: AppState, e: SelfTestEditor, f: FindBarScratch) -> SelfTestStep {
        SelfTestStep(name: "find escape closes", until: {
            if f.posted < 3, findFieldFocused(e) {
                f.posted = SelfTestKeys.post("esc", window: SelfTestKeys.mainWindow) ? 3 : f.posted
            }
            return f.posted == 3 && !state.showFind
        }, timeout: 4, run: {
            f.posted = 0
            e.activate()
            state.showFind = true
        }, check: {
            e.expect(!state.showFind && e.view?.window?.firstResponder === e.view, "find \(state.showFind) posted \(f.posted)")
        })
    }
}
