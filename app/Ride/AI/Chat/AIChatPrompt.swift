import Foundation

enum AIChatPrompt {
    static let system = """
    You are the coding assistant inside Ride, a native macOS IDE for Rust, C and C++. Each user message may start with code attached from the open project inside <context> tags (the selection, the item that encloses it, definitions of the symbols it uses, or whole files), followed by the question. Answer for exactly this code. Use markdown; put code in fenced blocks tagged with the language. When you refer to a place in the project, write it as path:line using the paths from the context so the editor can link it. If the attached code was cut short, say what you could not see instead of guessing. Keep prose short and direct.
    """

    static func turns(_ messages: [AIChatMessage]) -> [AIChatTurn] {
        let kept = messages
            .filter { !$0.streaming && $0.error == nil }
            .filter { $0.role == .user || !$0.text.isEmpty }
        var out: [AIChatTurn] = []
        for message in kept {
            let text = content(message)
            if let last = out.last, last.role == message.role {
                out[out.count - 1] = AIChatTurn(role: last.role, text: last.text + "\n\n" + text)
            } else {
                out.append(AIChatTurn(role: message.role, text: text))
            }
        }
        return out
    }

    static func content(_ message: AIChatMessage) -> String {
        guard message.role == .user, !message.attachments.isEmpty else {
            return message.text
        }
        let blocks = message.attachments.map(block)
        return blocks.joined(separator: "\n\n") + "\n\n" + message.text
    }

    static func block(_ attachment: AIChatAttachment) -> String {
        let cut = attachment.truncated ? " truncated=\"true\"" : ""
        return "<context kind=\"\(attachment.kind.rawValue)\" path=\"\(attachment.path)\" line=\"\(attachment.line)\"\(cut)>\n\(attachment.text)\n</context>"
    }

    static func title(for question: String) -> String {
        let line = question.split(separator: "\n").first.map(String.init) ?? question
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 48 ? String(trimmed.prefix(47)) + "…" : (trimmed.isEmpty ? "New chat" : trimmed)
    }
}
