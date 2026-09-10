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
    var parseUnderlines: [NSRange] = []
    var diagnosticUnderlines: [DiagnosticUnderline] = []
    var diagnosticsVersion: UInt64 = 0
    var highlights: [HighlightSpan] = []
    var visibleWork: DispatchWorkItem?
    var isReadOnly = false
    var detectedLanguage: BufferLanguage?
    var usesCRLF = false
    var changedOnDisk = false

    var hasCompletions: Bool {
        language.hasCompletions
    }

    var hasSession: Bool {
        language != .plain
    }

    var language: BufferLanguage {
        detectedLanguage ?? BufferLanguage.of(fileURL)
    }

    init(url: URL) {
        fileURL = url.standardizedFileURL
        untitledIndex = nil
        let loaded = Self.load(url.standardizedFileURL)
        text = loaded?.text ?? ""
        usesCRLF = loaded?.crlf ?? false
    }

    static func load(_ url: URL) -> (text: String, crlf: Bool)? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let raw = String(decoding: data, as: UTF8.self)
        let crlf = raw.contains("\r\n")
        return (crlf ? raw.replacingOccurrences(of: "\r\n", with: "\n") : raw, crlf)
    }

    func reload() -> Bool {
        guard let fileURL, let loaded = Self.load(fileURL) else {
            return false
        }
        text = loaded.text
        usesCRLF = loaded.crlf
        isDirty = false
        return true
    }

    func differsFromDisk() -> Bool {
        guard let fileURL, let loaded = Self.load(fileURL) else {
            return false
        }
        return loaded.text != text
    }

    var lineEnding: String {
        usesCRLF ? "CRLF" : "LF"
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
        textView.folds.removeAll()
        textView.selectionStack = []
        textView.string = text
        textView.lines.invalidate()
        isDirty = false
        updateLabel(textView)
        textView.isEditable = !isReadOnly
        textView.updateCurrentLineHighlight()
    }

    func updateLabel(_ textView: RideTextView) {
        let label = language.title.map { "\(displayName) \($0)" } ?? displayName
        textView.setAccessibilityLabel(label)
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
        let output = usesCRLF ? text.replacingOccurrences(of: "\n", with: "\r\n") : text
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
        changedOnDisk = false
        isDirty = false
        RideEngineClient.shared.engine?.workspaceFileChanged(path: fileURL.path)
    }
}
