import AppKit

enum AIContextBuilder {
    static let sourceExtensions: Set<String> = ["rs", "c", "h", "cc", "cpp", "cxx", "hh", "hpp", "toml", "cmake", "md", "py", "swift", "go", "js", "ts", "java", "kt", "rb", "sh"]
    static let sourceNames: Set<String> = ["Makefile", "CMakeLists.txt", "Cargo.toml"]

    static func plan(document: BufferDocument, view: RideTextView, state: AppState, level: AIContextLevel) -> AIContextPlan {
        let text = view.string
        let ns = text as NSString
        let caret = min(view.selectedRange().location, ns.length)
        let scope = scope(level, document: document, text: text, caret: caret)
        let root = state.workspaceRoot
        let (open, scan, budget) = extras(level, document: document, state: state)
        return AIContextPlan(
            language: document.language.title ?? "text",
            path: document.fileURL.map { relative($0, root: root) } ?? document.displayName,
            prefix: ns.substring(with: NSRange(location: scope.location, length: caret - scope.location)),
            suffix: ns.substring(with: NSRange(location: caret, length: NSMaxRange(scope) - caret)),
            open: open,
            scan: scan,
            root: root,
            budget: budget
        )
    }

    static func relative(_ url: URL, root: URL?) -> String {
        root.map { WorkspaceFS.relativePath(root: $0, file: url) } ?? url.lastPathComponent
    }

    private static func scope(_ level: AIContextLevel, document: BufferDocument, text: String, caret: Int) -> NSRange {
        let full = NSRange(location: 0, length: (text as NSString).length)
        switch level {
        case .block:
            return enclosing(document, text: text, caret: caret, innermost: true) ?? lines(around: caret, text: text, count: 40)
        case .function:
            return outlineRange(document, text: text, caret: caret)
                ?? enclosing(document, text: text, caret: caret, innermost: false)
                ?? lines(around: caret, text: text, count: 80)
        case .file, .directory, .project:
            return full
        }
    }

    private static func enclosing(_ document: BufferDocument, text: String, caret: Int, innermost: Bool) -> NSRange? {
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: caret))
        let map = Utf16Map(text)
        let found = SessionService.shared.readNow(document) { $0.enclosingRanges(sessionId: $1, startByte: byte, endByte: byte) }
        let ranges = (found ?? []).map { map.nsRange(startByte: $0.startByte, endByte: $0.endByte) }
        let multiline = ranges.filter { (text as NSString).substring(with: $0).contains("\n") }
        return innermost ? multiline.first : multiline.last
    }

    private static func outlineRange(_ document: BufferDocument, text: String, caret: Int) -> NSRange? {
        let byte = Utf16.utf8Offset(in: text, utf16: caret)
        let rows = document.outline.filter { Int($0.startByte) <= byte && byte <= Int($0.endByte) }
        guard let row = rows.min(by: { $0.endByte - $0.startByte < $1.endByte - $1.startByte }) else {
            return nil
        }
        return Utf16.nsRange(in: text, startByte: row.startByte, endByte: row.endByte)
    }

    private static func lines(around caret: Int, text: String, count: Int) -> NSRange {
        let ns = text as NSString
        var start = ns.lineRange(for: NSRange(location: caret, length: 0)).location
        var end = NSMaxRange(ns.lineRange(for: NSRange(location: caret, length: 0)))
        for _ in 0 ..< count {
            if start > 0 {
                start = ns.lineRange(for: NSRange(location: start - 1, length: 0)).location
            }
            if end < ns.length {
                end = NSMaxRange(ns.lineRange(for: NSRange(location: end, length: 0)))
            }
        }
        return NSRange(location: start, length: end - start)
    }

    private static func extras(_ level: AIContextLevel, document: BufferDocument, state: AppState) -> ([AIExtraFile], AISourceScan?, Int) {
        switch level {
        case .block, .function, .file:
            return ([], nil, 0)
        case .directory:
            guard let url = document.fileURL else {
                return ([], nil, 0)
            }
            let scan = AISourceScan(directory: url.deletingLastPathComponent(), depth: 0, excluded: [url.standardizedFileURL])
            return ([], scan, 40_000)
        case .project:
            let others = state.buffers.filter { $0 !== document }
            let open = others.compactMap { buffer in
                buffer.fileURL.map {
                    AIExtraFile(path: relative($0, root: state.workspaceRoot), text: AIContextWindow.head(buffer.text, limit: AIContextWindow.fileLimit))
                }
            }
            let excluded = Set(state.buffers.compactMap { $0.fileURL?.standardizedFileURL })
            let scan = state.workspaceRoot.map { AISourceScan(directory: $0, depth: 4, excluded: excluded) }
            return (open, scan, 100_000)
        }
    }
}
