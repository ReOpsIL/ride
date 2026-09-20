import AppKit

extension SelfTestSteps {
    static func callHierarchy(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "call hierarchy", wait: 0.4, until: {
            if state.activeBuffer?.fileURL?.lastPathComponent != "main.rs" {
                openMain(state)
                return false
            }
            if state.activeBuffer?.sessionId == nil {
                return false
            }
            if !e.line(10).contains(".record(") {
                restoreRecordCalls(e)
                return false
            }
            if state.hierarchy.running {
                return false
            }
            if state.hierarchy.finished, state.hierarchy.rootName == "record", state.hierarchy.childCount >= 2 {
                return true
            }
            placeOnRecord(e)
            state.indexOpenBuffers()
            state.showCallHierarchy()
            return false
        }, timeout: 30, run: {
            e.activate()
            openMain(state)
        }, check: {
            e.expect(
                state.showHierarchy && state.hierarchy.rootName == "record" && state.hierarchy.childCount >= 2,
                "root \(state.hierarchy.rootName) children \(state.hierarchy.childCount) shown \(state.showHierarchy) line10 \(e.line(10)) session \(state.activeBuffer?.sessionId ?? 0)"
            )
        })
    }

    private static func openMain(_ state: AppState) {
        guard let url = state.workspaceRoot?.appendingPathComponent("src/main.rs") else {
            return
        }
        state.openFile(url)
    }

    private static func placeOnRecord(_ e: SelfTestEditor) {
        guard let view = e.view else {
            return
        }
        let found = (view.string as NSString).range(of: ".record(")
        guard found.location != NSNotFound else {
            return
        }
        view.setSelectedRange(NSRange(location: found.location + 1, length: 0))
    }

    private static func restoreRecordCalls(_ e: SelfTestEditor) {
        guard let view = e.view else {
            return
        }
        replaceAll(view, of: ".logged(", with: ".record(")
        replaceAll(view, of: "tally", with: "counter")
    }

    private static func replaceAll(_ view: RideTextView, of needle: String, with replacement: String) {
        let ns = view.string as NSString
        var search = NSRange(location: 0, length: ns.length)
        while true {
            let found = (view.string as NSString).range(of: needle, options: [], range: search)
            guard found.location != NSNotFound else {
                return
            }
            view.insertText(replacement, replacementRange: found)
            let next = found.location + (replacement as NSString).length
            let end = (view.string as NSString).length
            if next >= end {
                return
            }
            search = NSRange(location: next, length: end - next)
        }
    }
}
