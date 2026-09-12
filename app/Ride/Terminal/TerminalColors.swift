import AppKit

struct TerminalColors: Equatable {
    let background: NSColor
    let foreground: NSColor
    let caret: NSColor
    let selection: NSColor

    static func from(_ theme: Theme) -> TerminalColors {
        TerminalColors(
            background: theme.editor.background,
            foreground: theme.chrome.textPrimary,
            caret: theme.editor.caret,
            selection: theme.editor.selection
        )
    }
}
