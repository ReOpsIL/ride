extension Preferences {
    var aiConfig: AIConfig {
        AIConfig(provider: aiProvider, model: aiModel, level: aiContext)
    }

    var aiChatConfig: AIConfig {
        let provider = AIProvider(rawValue: aiProvider) ?? .anthropic
        let model = assistant.chatModel.trimmingCharacters(in: .whitespaces)
        return AIConfig(provider: aiProvider, model: model.isEmpty ? provider.defaultChatModel : model, level: aiContext)
    }
}
