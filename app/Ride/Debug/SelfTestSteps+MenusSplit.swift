import AppKit

extension SelfTestSteps {
    static func menusSplit(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let panes = { state.paneLayout.panes.count }
        let probeID = { state.buffers.first { $0.fileURL == c.probeURL }?.id }
        let probeInRight = { () -> Bool in
            guard let id = probeID(), state.paneLayout.panes.count > 1 else {
                return false
            }
            return state.paneLayout.pane(showing: id)?.id == state.paneLayout.panes[1].id
        }
        return [
            c.step("menu toggle split", "View › Toggle Split", prepare: { state.closeSplit() }) {
                (state.splitLayout.isSplit && panes() == 2, "split \(state.splitLayout.isSplit) panes \(panes())")
            },
            c.step("menu close split", "View › Close Split") {
                (!state.splitLayout.isSplit && panes() == 1, "split \(state.splitLayout.isSplit) panes \(panes())")
            },
            c.step("menu open in split", "View › Open in Split", wait: 0.5, prepare: { c.openProbe() }) {
                (state.splitLayout.isSplit && probeInRight(), "split \(state.splitLayout.isSplit) panes \(panes()) right \(probeInRight())")
            },
            c.step("menu open in split close", "View › Close Split", wait: 0.5) {
                let kept = probeID().map { state.paneLayout.pane(showing: $0) != nil } ?? false
                return (!state.splitLayout.isSplit && panes() == 1 && kept, "split \(state.splitLayout.isSplit) kept \(kept)")
            },
        ]
    }
}
