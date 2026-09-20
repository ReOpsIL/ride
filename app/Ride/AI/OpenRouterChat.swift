import Foundation

enum OpenRouterChat {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    static let keyAccount = "openrouter"

    static func request(system: String, user: String, kind: AIRequestKind, config: AIConfig) -> Result<URLRequest, AIError> {
        guard let key = Keychain.read(keyAccount) else {
            return .failure(.notConfigured("No OpenRouter API key saved. Open Preferences › AI"))
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("https://github.com/ReOpsIL/ride", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Ride", forHTTPHeaderField: "X-Title")
        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": kind.maxTokens,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.malformed)
        }
        request.httpBody = data
        return .success(request)
    }

    static func text(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else {
            return nil
        }
        if let content = message["content"] as? String {
            return content
        }
        let parts = message["content"] as? [[String: Any]] ?? []
        let texts = parts.compactMap { $0["text"] as? String }
        return texts.isEmpty ? nil : texts.joined()
    }
}
