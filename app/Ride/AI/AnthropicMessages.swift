import Foundation

enum AnthropicMessages {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let keyAccount = "anthropic"
    private static let effortModels = ["claude-opus-5", "claude-sonnet-5", "claude-fable", "claude-opus-4-6", "claude-opus-4-7", "claude-opus-4-8", "claude-sonnet-4-6"]
    private static let fallbackModels = ["claude-opus-5", "claude-fable"]

    static func request(system: String, user: String, kind: AIRequestKind, config: AIConfig) -> Result<URLRequest, AIError> {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        var betas: [String] = []
        switch config.auth {
        case .login:
            guard AnthropicLogin.executable != nil else {
                return .failure(.notConfigured("Log in with your Anthropic account requires the Anthropic CLI (\(AnthropicLogin.installCommand))"))
            }
            guard let token = AnthropicLogin.accessToken() else {
                return .failure(.notConfigured("Not logged in to Anthropic. Open Preferences › AI and log in"))
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            betas.append("oauth-2025-04-20")
        case .key:
            guard let key = Keychain.read(keyAccount) else {
                return .failure(.notConfigured("No Anthropic API key saved. Open Preferences › AI"))
            }
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }
        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": kind.maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        if kind == .completion {
            var output: [String: Any] = ["format": ["type": "json_schema", "schema": AIPrompt.schema]]
            if effortModels.contains(where: config.model.hasPrefix) {
                output["effort"] = "low"
            }
            body["output_config"] = output
        }
        if fallbackModels.contains(where: config.model.hasPrefix) {
            body["fallbacks"] = "default"
            betas.append("server-side-fallback-2026-07-01")
        }
        if !betas.isEmpty {
            request.setValue(betas.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.malformed)
        }
        request.httpBody = data
        return .success(request)
    }

    static func text(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if object["stop_reason"] as? String == "refusal" {
            return "The provider declined this request."
        }
        let blocks = object["content"] as? [[String: Any]] ?? []
        let texts = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }
        return texts.isEmpty ? nil : texts.joined()
    }
}
