import AppKit

extension SelfTestSteps {
    static func codeVision(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "code vision", wait: 0.4, until: {
            if state.activeBuffer?.fileURL?.lastPathComponent != "util.rs" {
                if let root = state.workspaceRoot {
                    state.openFile(root.appendingPathComponent("src/util.rs"))
                }
                return false
            }
            guard let document = state.activeBuffer else {
                return false
            }
            if document.outline.contains(where: { $0.name == "record" }) == false {
                return false
            }
            if document.visionCounts["record"] != nil, e.view?.visionLabel(forLine: 10) != nil {
                return true
            }
            UsageCounter.refresh(document: document)
            e.view?.refreshVision(from: [])
            e.view?.layoutSubtreeIfNeeded()
            return false
        }, timeout: 30, run: {
            e.activate()
        }, check: {
            let document = state.activeBuffer
            let count = document?.visionCounts["record"]
            let label = e.view?.visionLabel(forLine: 10) ?? "nil"
            return e.expect(
                count == 5 && label.contains("usage"),
                "count \(count.map(String.init) ?? "nil") label \(label) outline \(document?.outline.map(\.name) ?? [])"
            )
        })
    }
}
