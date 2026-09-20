import AppKit

struct AIContextPlan {
    let language: String
    let path: String
    let prefix: String
    let suffix: String
    let open: [AIExtraFile]
    let files: [URL]
    let root: URL?
    let budget: Int

    func load() -> AIPromptInput {
        var extras = open
        var used = extras.reduce(0) { $0 + $1.text.count }
        for url in files where used < budget {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let clipped = AIContextWindow.head(text, limit: AIContextWindow.fileLimit)
            extras.append(AIExtraFile(path: AIContextBuilder.relative(url, root: root), text: clipped))
            used += clipped.count
        }
        let window = AIContextWindow.clip(prefix: prefix, suffix: suffix)
        return AIPromptInput(language: language, path: path, prefix: window.prefix, suffix: window.suffix, extras: extras)
    }
}

enum AIContextBuilder {
    static let sourceExtensions: Set<String> = ["rs", "c", "h", "cc", "cpp", "cxx", "hh", "hpp", "toml", "cmake", "md", "py", "swift", "go", "js", "ts", "java", "kt", "rb", "sh"]
    static let sourceNames: Set<String> = ["Makefile", "CMakeLists.txt", "Cargo.toml"]

    static func plan(document: BufferDocument, view: RideTextView, state: AppState, level: AIContextLevel) -> AIContextPlan {
        let text = view.string
        let ns = text as NSString
        let caret = min(view.selectedRange().location, ns.length)
        let scope = scope(level, document: document, text: text, caret: caret)
        let root = state.workspaceRoot
        let (open, files, budget) = extras(level, document: document, state: state)
        return AIContextPlan(
            language: document.language.title ?? "text",
            path: document.fileURL.map { relative($0, root: root) } ?? document.displayName,
            prefix: ns.substring(with: NSRange(location: scope.location, length: caret - scope.location)),
            suffix: ns.substring(with: NSRange(location: caret, length: NSMaxRange(scope) - caret)),
            open: open,
            files: files,
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
        guard let id = document.sessionId, let engine = RideEngineClient.shared.engine else {
            return nil
        }
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: caret))
        let ranges = engine.enclosingRanges(sessionId: id, startByte: byte, endByte: byte)
            .map { Utf16.nsRange(in: text, startByte: $0.startByte, endByte: $0.endByte) }
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

    private static func extras(_ level: AIContextLevel, document: BufferDocument, state: AppState) -> ([AIExtraFile], [URL], Int) {
        switch level {
        case .block, .function, .file:
            return ([], [], 0)
        case .directory:
            guard let url = document.fileURL else {
                return ([], [], 0)
            }
            let siblings = sources(in: url.deletingLastPathComponent(), depth: 0).filter { $0 != url }
            return ([], siblings, 40_000)
        case .project:
            let open = state.buffers.filter { $0 !== document && $0.fileURL != nil }.map { buffer in
                AIExtraFile(path: relative(buffer.fileURL!, root: state.workspaceRoot), text: AIContextWindow.head(buffer.text, limit: AIContextWindow.fileLimit))
            }
            let openURLs = Set(state.buffers.compactMap { $0.fileURL?.standardizedFileURL })
            let files = state.workspaceRoot.map { sources(in: $0, depth: 4) }?.filter { !openURLs.contains($0.standardizedFileURL) } ?? []
            return (open, files, 100_000)
        }
    }

    private static func sources(in directory: URL, depth: Int) -> [URL] {
        var out: [URL] = []
        for node in WorkspaceFS.children(of: directory, showHidden: false) {
            if node.isDirectory {
                if depth > 0 {
                    out += sources(in: node.url, depth: depth - 1)
                }
            } else if sourceExtensions.contains(node.url.pathExtension.lowercased()) || sourceNames.contains(node.name) {
                out.append(node.url)
            }
        }
        return out
    }
}
