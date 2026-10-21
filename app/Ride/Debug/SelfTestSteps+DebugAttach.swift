import Foundation

extension SelfTestSteps {
    static func menuDebugAttach(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let model = state.attachModel
        let own = UInt32(ProcessInfo.processInfo.processIdentifier)
        return menuStep("menu debug attach", "Debug › Attach to Process…", timeout: 15, done: {
            model.visible && !model.loading && !model.rows.isEmpty
        }) { pressed in
            let listed = model.rows.count
            let hidesRide = !model.rows.contains { $0.pid == own }
            let shown = model.visible
            model.cancel()
            return e.expect(
                pressed && shown && listed > 0 && hidesRide && !model.visible,
                "pressed \(pressed) shown \(shown) rows \(listed) hides Ride \(hidesRide)"
            )
        }
    }
}
