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
    var highlights: [HighlightSpan] = []
    var visibleWork: DispatchWorkItem?
    var isReadOnly = false

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
        isDirty = false
        let label = fileURL?.pathExtension == "rs" ? "\(displayName) Rust" : displayName
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

func lineAndColumn(in string: String, utf16: Int) -> (Int, Int) {
    let ns = string as NSString
    let loc = min(max(utf16, 0), ns.length)
    var lineStart = 0
    ns.getLineStart(&lineStart, end: nil, contentsEnd: nil, for: NSRange(location: loc, length: 0))
    let prefix = ns.substring(to: loc)
    let line = prefix.split(separator: "\n", omittingEmptySubsequences: false).count
    return (line, loc - lineStart + 1)
}
