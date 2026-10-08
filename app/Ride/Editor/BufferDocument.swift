import AppKit
import SwiftUI

final class BufferDocument: ObservableObject, Identifiable {
    let id = UUID()
    var fileURL: URL?
    let untitledIndex: Int?
    var text: String
    @Published var isDirty = false
    @Published var showHtmlSource = false
    @Published private(set) var htmlGeneration = 0
    @Published var outline: [OutlineRow] = [] {
        didSet { visionInputs &+= 1 }
    }
    var sessionId: UInt64?
    var editCount = 0
    var pending: PendingEdit?
    var parseUnderlines: [NSRange] = []
    var diagnosticUnderlines: [DiagnosticUnderline] = []
    var diagnosticsVersion: UInt64 = 0
    var highlights: [HighlightSpan] = []
    var visibleWork: DispatchWorkItem?
    @Published var isReadOnly = false
    var detectedLanguage: BufferLanguage?
    var usesCRLF = false
    var changedOnDisk = false
    var caretByte: UInt32 = 0
    var scrollLine: UInt32 = 1
    var foldStarts: [UInt32] = []
    var diskText: String
    var pendingText: PendingText?
    var pendingJump: PendingJump?
    var sessionGeneration = 0
    var sessionOpening = false
    var visionCounts: [String: Int] = [:] {
        didSet { visionInputs &+= 1 }
    }
    private(set) var visionInputs = 0
    var visionGeneration = 0
    var autoSaveWork: DispatchWorkItem?
    var journal = EditJournal()
    lazy var undo = BufferUndo(document: self)

    var textGeneration: Int {
        journal.generation
    }

    var undoManager: UndoManager {
        undo.manager
    }

    var hasCompletions: Bool {
        language.hasCompletions
    }

    var hasSession: Bool {
        language != .plain
    }

    var language: BufferLanguage {
        detectedLanguage ?? BufferLanguage.sniff(url: fileURL, text: text)
    }

    init(url: URL) {
        fileURL = url.standardizedFileURL
        untitledIndex = nil
        let loaded = Self.load(url.standardizedFileURL)
        text = loaded?.text ?? ""
        diskText = text
        usesCRLF = loaded?.crlf ?? false
    }

    init(untitled index: Int) {
        fileURL = nil
        untitledIndex = index
        text = ""
        diskText = ""
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

    func replaceDetached(_ next: String) {
        journal.record(ByteEdit(start: 0, oldEnd: UInt32(text.utf8.count), newEnd: UInt32(next.utf8.count)))
        text = next
        highlights = []
        undo.manager.removeAllActions()
        htmlGeneration += 1
    }

    func bind(_ textView: RideTextView) {
        let caret = caretByte
        let scroll = scrollLine
        textView.undoSteps = undo
        textView.folds.removeAll()
        textView.selectionStack = []
        textView.string = text
        textView.lines.invalidate()
        updateLabel(textView)
        textView.isEditable = !isReadOnly
        caretByte = caret
        scrollLine = scroll
        restoreCaretAndScroll(textView)
        textView.updateCurrentLineHighlight()
    }

    private func restoreCaretAndScroll(_ textView: RideTextView) {
        let ns = text as NSString
        let loc = min(Utf16.utf16Offset(in: text, utf8: Int(caretByte)), ns.length)
        let starts = textView.lineIndex().starts
        if !starts.isEmpty {
            let line = min(max(Int(scrollLine), 1), starts.count)
            textView.scrollRangeToVisible(NSRange(location: starts[line - 1], length: 1))
        }
        textView.setSelectedRange(NSRange(location: loc, length: 0))
    }

    func updateLabel(_ textView: RideTextView) {
        let label = language.title.map { "\(displayName) \($0)" } ?? displayName
        textView.setAccessibilityLabel(label)
    }

    func capture(_ textView: RideTextView) {
        text = textView.string
        caretByte = UInt32(Utf16.utf8Offset(in: text, utf16: textView.selectedRange().location))
        scrollLine = UInt32(max(1, textView.firstVisibleLine()))
        foldStarts = textView.folds.ranges.map { range in
            UInt32(Utf16.utf8Offset(in: text, utf16: range.location))
        }
    }
}
