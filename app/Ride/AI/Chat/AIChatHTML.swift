import Foundation

enum AIChatHTML {
    static func message(_ message: AIChatMessage, render: (String) -> String) -> String {
        switch message.role {
        case .user:
            return user(message)
        case .assistant:
            return assistant(message, render: render)
        }
    }

    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func user(_ message: AIChatMessage) -> String {
        let chips = message.attachments.map { attachment in
            "<a class=\"chip\" href=\"ride-open:\(escape(attachment.path)):\(attachment.line)\">\(escape(attachment.label))</a>"
        }.joined()
        let text = escape(message.text).replacingOccurrences(of: "\n", with: "<br>")
        let row = chips.isEmpty ? "" : "<div class=\"chips\">\(chips)</div>"
        return "<div class=\"msg user\">\(row)<div class=\"q\">\(text)</div></div>"
    }

    private static func assistant(_ message: AIChatMessage, render: (String) -> String) -> String {
        var body = message.text.isEmpty ? "" : render(message.text)
        if message.streaming {
            body += message.text.isEmpty ? "<p class=\"wait\">Thinking…</p>" : "<span class=\"caret\"></span>"
        }
        if let error = message.error {
            body += "<p class=\"err\">\(escape(error))</p>"
        }
        return "<div class=\"msg assistant\">\(body)</div>"
    }
}
