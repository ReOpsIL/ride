import AppKit

extension SelfTestSteps {
    static func prefAISteps(state: AppState, e: SelfTestEditor, bind: PreferenceBindings) -> [SelfTestStep] {
        [
            aiScheduleStep("pref ai suggestions off", e: e, set: { bind.bool(\.aiComplete).wrappedValue = false }, expected: false),
            aiScheduleStep("pref ai suggestions on", e: e, set: { bind.bool(\.aiComplete).wrappedValue = true }, expected: true),
            SelfTestStep(name: "pref ai context", run: { bind.string(\.aiContext).wrappedValue = AIContextLevel.file.rawValue }, check: {
                let level = state.prefs.aiConfig.level
                bind.string(\.aiContext).wrappedValue = Preferences.defaults.aiContext
                return e.expect(level == .file && state.prefs.aiConfig.level == .function, "level \(level)")
            }),
            SelfTestStep(name: "pref ai model", run: { bind.string(\.aiModel).wrappedValue = "ride-probe-model" }, check: {
                let model = state.prefs.aiConfig.model
                bind.string(\.aiModel).wrappedValue = ""
                let fallback = state.prefs.aiConfig.model
                return e.expect(model == "ride-probe-model" && fallback == state.prefs.aiConfig.provider.defaultModel, "model \(model) fallback \(fallback)")
            }),
            providerResetsModel(state: state, e: e, bind: bind),
        ]
    }

    private static func providerResetsModel(state: AppState, e: SelfTestEditor, bind: PreferenceBindings) -> SelfTestStep {
        var original = AIProvider.anthropic
        return SelfTestStep(name: "pref ai provider resets model", run: {
            original = state.prefs.aiConfig.provider
            bind.string(\.aiModel).wrappedValue = "ride-probe-model"
            bind.provider.wrappedValue = (original == .anthropic ? AIProvider.openrouter : .anthropic).rawValue
        }, check: {
            let config = state.prefs.aiConfig
            let cleared = state.prefs.aiModel.isEmpty
            bind.provider.wrappedValue = original.rawValue
            return e.expect(config.provider != original && config.model == config.provider.defaultModel && cleared && state.prefs.aiConfig.provider == original,
                            "provider \(config.provider) model \(config.model)")
        })
    }

    private static func aiScheduleStep(_ name: String, e: SelfTestEditor, set: @escaping () -> Void, expected: Bool) -> SelfTestStep {
        var scheduled = !expected
        return SelfTestStep(name: name, run: {
            set()
            e.place(on: "counter.record(\"ride\");", atEnd: true)
            e.type("c")
            scheduled = AICompletionSource.shared.isScheduled || AIInlineController.shared.isScheduled
            AISuggestRouter.cancel()
            e.view?.deleteBackward(nil)
            CompletionSession.shared.hide()
            if expected {
                e.state.updatePrefs { $0.aiComplete = false }
            }
        }, check: {
            e.expect(scheduled == expected, "scheduled \(scheduled)")
        })
    }
}
