import Foundation

enum AIStreamRequest {
    static let maxTokens = 32_000

    static func build(system: String, turns: [AIChatTurn], config: AIConfig) -> Result<URLRequest, AIError> {
        switch config.provider {
        case .anthropic:
            return anthropic(system: system, turns: turns, config: config)
        case .openrouter:
            return openRouter(system: system, turns: turns, config: config)
        }
    }

    static func decoder(for provider: AIProvider) -> AIStreamDecoder {
        switch provider {
        case .anthropic: return AnthropicStreamDecoder()
        case .openrouter: return OpenRouterStreamDecoder()
        }
    }

    private static func anthropic(system: String, turns: [AIChatTurn], config: AIConfig) -> Result<URLRequest, AIError> {
        guard let key = AICredentials.key(AnthropicMessages.keyAccount) else {
            return .failure(.notConfigured("No Anthropic API key saved. Open Preferences › AI"))
        }
        var request = URLRequest(url: AnthropicMessages.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": system,
            "cache_control": ["type": "ephemeral"],
            "messages": turns.map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        if AnthropicMessages.usesFallbacks(config.model) {
            body["fallbacks"] = "default"
            request.setValue(AnthropicMessages.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        return encode(body, into: request)
    }

    private static func openRouter(system: String, turns: [AIChatTurn], config: AIConfig) -> Result<URLRequest, AIError> {
        guard let key = AICredentials.key(OpenRouterChat.keyAccount) else {
            return .failure(.notConfigured("No OpenRouter API key saved. Open Preferences › AI"))
        }
        var request = URLRequest(url: OpenRouterChat.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("https://github.com/ReOpsIL/ride", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Ride", forHTTPHeaderField: "X-Title")
        let messages = [["role": "system", "content": system]] + turns.map { ["role": $0.role.rawValue, "content": $0.text] }
        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": messages,
        ]
        return encode(body, into: request)
    }

    private static func encode(_ body: [String: Any], into request: URLRequest) -> Result<URLRequest, AIError> {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.malformed)
        }
        var request = request
        request.httpBody = data
        return .success(request)
    }
}
