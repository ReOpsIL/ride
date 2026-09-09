import AppKit

final class CompletionSelectionRow: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else {
            return
        }
        let rect = bounds.insetBy(dx: Tokens.Space.xs, dy: 1)
        ThemeStore.shared.chrome.accent.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: rect, xRadius: Tokens.Radius.m, yRadius: Tokens.Radius.m).fill()
    }

    override func drawBackground(in dirtyRect: NSRect) {}
}
