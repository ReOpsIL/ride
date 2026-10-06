import Foundation

enum AIChatAttachmentKind: String, Equatable {
    case selection
    case file
    case enclosing
    case definition
}

struct AIChatAttachment: Equatable, Identifiable {
    let id = UUID()
    let kind: AIChatAttachmentKind
    let path: String
    let line: Int
    let text: String
    let truncated: Bool

    var lineCount: Int {
        max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count - (text.hasSuffix("\n") ? 1 : 0))
    }

    var label: String {
        let name = (path as NSString).lastPathComponent
        let shown = name.isEmpty ? "untitled" : name
        switch kind {
        case .file:
            return shown
        case .selection, .enclosing, .definition:
            return lineCount > 1 ? "\(shown):\(line)-\(line + lineCount - 1)" : "\(shown):\(line)"
        }
    }

    static func == (a: AIChatAttachment, b: AIChatAttachment) -> Bool {
        a.kind == b.kind && a.path == b.path && a.line == b.line && a.text == b.text
    }
}

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: AIChatRole
    var text: String
    var attachments: [AIChatAttachment] = []
    var streaming = false
    var error: String?

    static func == (a: AIChatMessage, b: AIChatMessage) -> Bool {
        a.id == b.id && a.text == b.text && a.streaming == b.streaming && a.error == b.error && a.attachments == b.attachments
    }
}

struct AIChatThread: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var messages: [AIChatMessage] = []
    let created = Date()

    static func == (a: AIChatThread, b: AIChatThread) -> Bool {
        a.id == b.id && a.title == b.title && a.messages == b.messages
    }
}
