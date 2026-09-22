import AppKit

final class GutterView: NSView {
    weak var textView: RideTextView?
    var diagnosticLines: [Int: DiagnosticLevel] = [:] {
        didSet { needsDisplay = true }
    }
    var runMarkers: [Int: TestMarkerRow] = [:] {
        didSet {
            if runMarkers != oldValue {
                needsDisplay = true
            }
        }
    }
    var intentionLines: Set<Int> = [] {
        didSet {
            if intentionLines != oldValue {
                needsDisplay = true
            }
        }
    }
    var breakpointLines: [Int: Bool] = [:] {
        didSet {
            if breakpointLines != oldValue {
                needsDisplay = true
            }
        }
    }
    var viewport: NSTextViewportLayoutController?
    static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    static let currentFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    static let glyphColumn: CGFloat = 14
    static let markerColumn: CGFloat = 13
    static let trailing: CGFloat = 8

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    static func width(digits: Int) -> CGFloat {
        let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
        return markerColumn + glyphColumn + digit * CGFloat(max(digits, 3)) + trailing + 4
    }

    func attach(textView: RideTextView) {
        self.textView = textView
        viewport = textView.textLayoutManager?.textViewportLayoutController
        FoldController.shared.refreshStarts(textView)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = ThemeStore.shared.theme
        theme.editor.background.setFill()
        bounds.intersection(dirtyRect).fill()
        if let textView, textView.folds.startsDirty {
            FoldController.shared.refreshStarts(textView)
        }
        guard let textView else {
            return
        }
        let index = textView.lineIndex()
        let currentLine = index.line(at: textView.selectedRange().location)
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: theme.editor.gutterText]
        let currentAttrs: [NSAttributedString.Key: Any] = [.font: Self.currentFont, .foregroundColor: theme.editor.gutterCurrent]
        enumerateVisibleLines { lineNo, dest in
            if dest.intersects(dirtyRect) {
                drawLine(lineNo, at: dest, attrs: lineNo == currentLine ? currentAttrs : attrs, theme: theme)
            }
            return true
        }
        theme.chrome.border.setStroke()
        let edge = NSBezierPath()
        edge.move(to: CGPoint(x: bounds.maxX - 0.5, y: 0))
        edge.line(to: CGPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        edge.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let line = line(at: point), let textView else {
            return
        }
        guard point.x < Self.markerColumn + Self.glyphColumn else {
            if let path = path(of: textView) {
                state(of: textView)?.toggleBreakpoint(path: path, line: UInt32(line))
            }
            return
        }
        if point.x < Self.markerColumn {
            runMarker(line, in: textView)
            return
        }
        if textView.folds.startsDirty {
            FoldController.shared.refreshStarts(textView)
        }
        guard textView.folds.isFoldStart(line: line) else {
            return
        }
        FoldController.shared.toggle(line: line)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard point.x >= Self.markerColumn + Self.glyphColumn, let line = line(at: point), let textView,
              let path = path(of: textView)
        else {
            return
        }
        state(of: textView)?.editBreakpoint(path: path, line: UInt32(line))
    }

    private func runMarker(_ line: Int, in textView: RideTextView) {
        guard let marker = runMarkers[line], let state = state(of: textView) else {
            return
        }
        state.runTestMarker(marker)
    }

    private func state(of textView: RideTextView) -> AppState? {
        textView.hooks.binding?()?.state
    }

    private func path(of textView: RideTextView) -> String? {
        textView.hooks.binding?()?.document.fileURL?.standardizedFileURL.path
    }

    private func drawLine(_ lineNo: Int, at dest: NSRect, attrs: [NSAttributedString.Key: Any], theme: Theme) {
        var attributes = attrs
        if let verified = breakpointLines[lineNo] {
            drawBreakpoint(verified: verified, at: dest, color: theme.chrome.error)
            attributes[.foregroundColor] = theme.editor.background
        }
        let label = "\(lineNo)" as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(
            at: CGPoint(x: bounds.width - size.width - Self.trailing, y: dest.midY - size.height / 2),
            withAttributes: attributes
        )
        if let textView, textView.folds.isFoldStart(line: lineNo) {
            let collapsed = textView.folds.startsFold(at: lineRange(lineNo, in: textView))
            drawChevron(collapsed: collapsed, at: dest, color: collapsed ? theme.chrome.accent : theme.editor.gutterText)
        } else if let level = diagnosticLines[lineNo] {
            let color = level == .error ? theme.chrome.error : theme.chrome.warning
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: Self.markerColumn + 5, y: dest.midY - 3, width: 6, height: 6)).fill()
        } else if intentionLines.contains(lineNo) {
            drawBulb(at: dest, color: theme.chrome.accent)
        }
        if runMarkers[lineNo] != nil {
            drawRunMarker(at: dest, color: theme.chrome.accent)
        }
    }
}
