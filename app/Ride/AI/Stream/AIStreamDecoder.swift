import Foundation

enum AIStreamPiece: Equatable {
    case text(String)
    case refused(String)
    case failed(String)
    case done
}

protocol AIStreamDecoder {
    func decode(data: String) -> AIStreamPiece?
}

struct AnthropicStreamDecoder: AIStreamDecoder {
    func decode(data: String) -> AIStreamPiece? {
        guard let object = AIStreamJSON.object(data) else {
            return nil
        }
        switch object["type"] as? String {
        case "content_block_delta":
            let delta = object["delta"] as? [String: Any]
            guard delta?["type"] as? String == "text_delta", let text = delta?["text"] as? String else {
                return nil
            }
            return .text(text)
        case "message_delta":
            let delta = object["delta"] as? [String: Any]
            return delta?["stop_reason"] as? String == "refusal" ? .refused("The provider declined this request.") : nil
        case "message_stop":
            return .done
        case "error":
            let error = object["error"] as? [String: Any]
            return .failed(error?["message"] as? String ?? "The provider reported an error")
        default:
            return nil
        }
    }
}

struct OpenRouterStreamDecoder: AIStreamDecoder {
    func decode(data: String) -> AIStreamPiece? {
        if data == "[DONE]" {
            return .done
        }
        guard let object = AIStreamJSON.object(data) else {
            return nil
        }
        if let error = object["error"] as? [String: Any] {
            return .failed(error["message"] as? String ?? "The provider reported an error")
        }
        let choice = (object["choices"] as? [[String: Any]])?.first
        let delta = choice?["delta"] as? [String: Any]
        if let text = delta?["content"] as? String, !text.isEmpty {
            return .text(text)
        }
        return nil
    }
}

enum AIStreamJSON {
    static func object(_ data: String) -> [String: Any]? {
        guard let bytes = data.data(using: .utf8) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any]
    }

    static func payload(ofLine line: String) -> String? {
        guard line.hasPrefix("data:") else {
            return nil
        }
        return line.dropFirst(5).trimmingCharacters(in: .whitespaces)
    }
}
