import AppKit

extension SelfTestSteps {
    static let labThrowFilter = "cpp_throw"

    static func labThrowSteps(state: AppState, e: SelfTestEditor, scratch: DebugLabScratch) -> [SelfTestStep] {
        let throwing = { (caller: String) in labTop(state, is: "__cxa_throw") && labFrames(state).contains { $0.contains(caller) } }
        return [
            labThrowToggle("lab cpp throw menu", state: state, e: e, scratch: scratch, restore: false),
            labDebug("lab cpp throw debug", state: state, scenario: "faults", ready: { throwing("parse_quantity") }) {
                e.expect(throwing("parse_quantity"), labWhere(state))
            },
            labKey("lab cpp throw continue", "Debug › Continue", state: state, ready: { throwing("validate") }) {
                e.expect(throwing("validate") && !throwing("parse_quantity"), labWhere(state))
            },
            labStop("lab cpp throw stop", state: state, e: e, scratch: scratch),
            labThrowToggle("lab cpp throw menu restore", state: state, e: e, scratch: scratch, restore: true),
        ]
    }

    private static func labThrowToggle(_ name: String, state: AppState, e: SelfTestEditor, scratch: DebugLabScratch, restore: Bool) -> SelfTestStep {
        let enabled = { DebugFilters.shared.toggles.first { $0.id == labThrowFilter }?.enabled }
        let wanted = { restore ? scratch.filter : true }
        return SelfTestStep(name: name, wait: 0.5, until: { enabled() == wanted() }, timeout: 10, run: {
            if !restore {
                scratch.filter = enabled()
            }
            guard let label = DebugFilters.shared.toggles.first(where: { $0.id == labThrowFilter })?.label, enabled() != wanted() else {
                return
            }
            scratch.pressed = SelfTestMenu.perform("Debug › \(label)")
        }, check: {
            e.expect(enabled() != nil && enabled() == wanted(), "filter \(enabled().map(String.init) ?? "missing") pressed \(scratch.pressed)")
        })
    }
}
