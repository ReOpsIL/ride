extension Preferences {
    var aiConfig: AIConfig {
        AIConfig(provider: aiProvider, model: aiModel, level: aiContext)
    }
}
