import AppKit

extension SelfTestSteps {
    static func exceptionFilterSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let before = SelfTestFilterScratch()
        return [exceptionFilterFlip(e: e, before: before, restore: false), exceptionFilterFlip(e: e, before: before, restore: true)]
    }

    private static func exceptionFilterFlip(e: SelfTestEditor, before: SelfTestFilterScratch, restore: Bool) -> SelfTestStep {
        SelfTestStep(name: restore ? "menu exception filters restore" : "menu exception filters", wait: 0.5, until: { !DebugFilters.shared.toggles.isEmpty }, timeout: 20, run: {}, check: {
            let filters = DebugFilters.shared
            if !restore {
                before.enabled = Dictionary(uniqueKeysWithValues: filters.toggles.map { ($0.id, $0.enabled) })
            }
            let pressed = filters.toggles.map { SelfTestMenu.perform("Debug › \($0.label)") }
            let expected = { (toggle: DebugFilterToggle) in restore ? before.enabled[toggle.id] : before.enabled[toggle.id].map { !$0 } }
            let wrong = filters.toggles.filter { expected($0) != $0.enabled }.map(\.label)
            return e.expect(
                !filters.toggles.isEmpty && !pressed.contains(false) && wrong.isEmpty,
                "filters \(filters.toggles.map(\.label)) pressed \(pressed) wrong \(wrong)"
            )
        })
    }
}

final class SelfTestFilterScratch {
    var enabled: [String: Bool] = [:]
}
