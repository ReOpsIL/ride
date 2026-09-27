import AppKit

final class ProjectFindScratch {
    var count = 0
    var posted = false
}

extension SelfTestSteps {
    static func projectFindSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let model = state.projectFind
        let f = ProjectFindScratch()
        let idle = { !model.running }
        return [
            SelfTestStep(name: "project find search and move", until: idle, timeout: 10, run: {
                state.toggleProjectFind()
                model.options = .defaults
                model.query = "record"
                state.projectFindSubmit()
            }, check: {
                f.count = model.matches.count
                model.move(1)
                let second = model.selection
                model.move(-2)
                let wrapped = model.selection
                return e.expect(f.count > 2 && second == 1 && wrapped == f.count - 1, "matches \(f.count) second \(String(describing: second)) wrapped \(String(describing: wrapped))")
            }),
            SelfTestStep(name: "project find options rerun", until: idle, timeout: 10, run: {
                model.options.wholeWord = true
                model.query = "count"
                state.projectFindSubmit()
            }, check: {
                let whole = model.matches.count
                model.options = .defaults
                return e.expect(whole > 0 && model.needsRun, "whole word \(whole) needsRun \(model.needsRun)")
            }),
            SelfTestStep(name: "project replace preview selection", until: idle, timeout: 10, run: {
                model.query = "record"
                model.replacement = "RECORD"
                state.projectFindPreview()
            }, check: {
                let shown = model.showPreview
                model.includeAll(false)
                let none = model.chosenHits.isEmpty
                model.includeAll(true)
                let all = model.chosenHits.count == model.hits.count && !model.hits.isEmpty
                model.showPreview = false
                return e.expect(shown && none && all && e.text.contains("record"), "preview \(shown) none \(none) all \(all)")
            }),
            SelfTestStep(name: "project find opens match", wait: 0.6, run: {
                state.projectFindSubmit()
            }, check: {
                e.expect(!state.showProjectFind && e.line(e.caretLine).contains("record"), "overlay \(state.showProjectFind) line '\(e.line(e.caretLine))'")
            }),
            showFile("show main before project find escape", state: state, e: e),
            SelfTestStep(name: "project find escape closes", until: {
                let responder = SelfTestKeys.mainWindow?.firstResponder
                if !f.posted, responder is NSTextView, !(responder is RideTextView) {
                    f.posted = SelfTestKeys.post("esc", window: SelfTestKeys.mainWindow)
                } else if !f.posted {
                    f.count += 1
                    if f.count % 4 == 0 {
                        state.showProjectFind = false
                        DemoLaunch.after(0.1) { state.showProjectFind = true }
                    }
                }
                return f.posted && !state.showProjectFind
            }, timeout: 6, run: {
                f.posted = false
                f.count = 0
                e.activate()
                state.toggleProjectFind()
            }, check: {
                let closed = !state.showProjectFind
                state.showProjectFind = false
                e.focus()
                let responder = SelfTestKeys.mainWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
                let key = NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "nil"
                return e.expect(f.posted && closed, "posted \(f.posted) closed \(closed) responder \(responder) key \(key) sheet \(SelfTestKeys.mainWindow?.attachedSheet != nil)")
            }),
        ]
    }
}
