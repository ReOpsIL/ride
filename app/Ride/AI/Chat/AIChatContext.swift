import AppKit

enum AIChatContext {
    static let budget: UInt32 = 24_000
    static let fileLimit = 60_000

    static func selection(view: RideTextView, document: BufferDocument, root: URL?) -> [AIChatAttachment] {
        let text = view.string
        var range = view.selectedRange()
        if range.length == 0 {
            range = enclosingItem(document, text: text, caret: range.location) ?? lineRange(text, caret: range.location)
        }
        let start = UInt32(Utf16.utf8Offset(in: text, utf16: range.location))
        let end = UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(range)))
        let pack = SessionService.shared.readNow(document) { engine, id in
            engine.aiContext(sessionId: id, startByte: start, endByte: end, budgetChars: budget)
        } ?? nil
        guard let pack else {
            let snippet = (text as NSString).substring(with: range)
            let line = (text as NSString).substring(to: range.location).components(separatedBy: "\n").count
            return [AIChatAttachment(kind: .selection, path: path(document, root: root), line: line, text: snippet, truncated: false)]
        }
        var out = [attachment(pack.focus, kind: .selection, root: root, fallback: path(document, root: root))]
        if let enclosing = pack.enclosing {
            out.append(attachment(enclosing, kind: .enclosing, root: root, fallback: path(document, root: root)))
        }
        out += pack.related.map { attachment($0, kind: .definition, root: root, fallback: path(document, root: root)) }
        return out
    }

    static func file(document: BufferDocument, text: String, root: URL?) -> AIChatAttachment {
        let clipped = AIContextWindow.head(text, limit: fileLimit)
        return AIChatAttachment(
            kind: .file,
            path: path(document, root: root),
            line: 1,
            text: clipped,
            truncated: clipped.count < text.count
        )
    }

    static func path(_ document: BufferDocument, root: URL?) -> String {
        document.fileURL.map { AIContextBuilder.relative($0, root: root) } ?? document.displayName
    }

    private static func attachment(_ snippet: AiSnippet, kind: AIChatAttachmentKind, root: URL?, fallback: String) -> AIChatAttachment {
        let path = snippet.path.isEmpty ? fallback : AIContextBuilder.relative(URL(fileURLWithPath: snippet.path), root: root)
        return AIChatAttachment(kind: kind, path: path, line: Int(snippet.line), text: snippet.text, truncated: snippet.truncated)
    }

    private static func enclosingItem(_ document: BufferDocument, text: String, caret: Int) -> NSRange? {
        let byte = Utf16.utf8Offset(in: text, utf16: caret)
        let rows = document.outline.filter { Int($0.startByte) <= byte && byte <= Int($0.endByte) }
        guard let row = rows.min(by: { $0.endByte - $0.startByte < $1.endByte - $1.startByte }) else {
            return nil
        }
        return Utf16.nsRange(in: text, startByte: row.startByte, endByte: row.endByte)
    }

    private static func lineRange(_ text: String, caret: Int) -> NSRange {
        (text as NSString).lineRange(for: NSRange(location: min(caret, (text as NSString).length), length: 0))
    }
}
