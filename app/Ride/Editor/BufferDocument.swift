import AppKit
import SwiftUI

final class BufferDocument: ObservableObject, Identifiable {
    let id = UUID()
    var fileURL: URL?
    let untitledIndex: Int?
    var text: String
    @Published var isDirty = false
    @Published var outline: [OutlineRow] = []
    var sessionId: UInt64?
    var editCount = 0
    var pending: PendingEdit?
    var errorRanges: [NSRange] = []
    var diagnosticRanges: [NSRange] = []
    var highlights: [HighlightSpan] = []
    var visibleWork: DispatchWorkItem?
    var isReadOnly = false

    var hasCompletions: Bool {
        language.hasCompletions
    }

    var hasSession: Bool {
        language != .plain
    }

    var language: BufferLanguage {
        BufferLanguage.of(fileURL)
    }

    init(url: URL) {
        fileURL = url.standardizedFileURL
        untitledIndex = nil
        if let data = try? Data(contentsOf: url.standardizedFileURL) {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    init(untitled index: Int) {
        fileURL = nil
        untitledIndex = index
        text = ""
    }

    var displayName: String {
        if let fileURL {
            return fileURL.lastPathComponent
        }
        if let untitledIndex, untitledIndex > 1 {
            return "Untitled \(untitledIndex)"
        }
        return "Untitled"
    }

    func bind(_ textView: RideTextView) {
        textView.string = text
        textView.lines.invalidate()
        isDirty = false
        let label = language.title.map { "\(displayName) \($0)" } ?? displayName
        textView.setAccessibilityLabel(label)
        textView.isEditable = !isReadOnly
        textView.updateCurrentLineHighlight()
    }

    func capture(_ textView: RideTextView) {
        text = textView.string
    }

    func save(from textView: RideTextView?) throws {
        if let textView {
            text = textView.string
        }
        guard let fileURL, !isReadOnly else {
            return
        }
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        isDirty = false
        RideEngineClient.shared.engine?.workspaceFileChanged(path: fileURL.path)
    }
}

enum BufferLanguage {
    case rust
    case c
    case cpp
    case markdown
    case plain

    static let cExtensions: Set<String> = ["c", "h"]
    static let cppExtensions: Set<String> = [
        "cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "inl", "ipp", "tpp", "cppm", "ixx",
    ]

    static func of(_ url: URL?) -> BufferLanguage {
        guard let url else {
            return .rust
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "rs": return .rust
        case "md", "markdown": return .markdown
        case _ where cExtensions.contains(ext): return .c
        case _ where cppExtensions.contains(ext): return .cpp
        default: return .plain
        }
    }

    var hasCompletions: Bool {
        switch self {
        case .rust, .c, .cpp: return true
        case .markdown, .plain: return false
        }
    }

    var title: String? {
        switch self {
        case .rust: return "Rust"
        case .c: return "C"
        case .cpp: return "C++"
        case .markdown, .plain: return nil
        }
    }
}
