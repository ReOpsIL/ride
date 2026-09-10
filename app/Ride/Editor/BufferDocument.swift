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
    var detectedLanguage: BufferLanguage?

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
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        isDirty = false
        RideEngineClient.shared.engine?.workspaceFileChanged(path: fileURL.path)
    }
}
