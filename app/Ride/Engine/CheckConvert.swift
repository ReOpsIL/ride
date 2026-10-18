import Foundation

enum CheckConvert {
    static func stored(_ diag: Diagnostic) -> StoredDiagnostic? {
        let level: ProblemLevel
        switch diag.level {
        case .error:
            level = .error
        case .warning:
            level = .warning
        case .note, .help:
            return nil
        }
        return StoredDiagnostic(
            primary: stored(diag.primary),
            level: level,
            message: diag.message,
            code: diag.code,
            fixes: diag.fixes.map(stored),
            secondary: diag.secondary.map(stored),
            notes: diag.notes.map(stored)
        )
    }

    static func stored(_ label: DiagnosticLabel) -> StoredLabel {
        StoredLabel(
            path: label.path,
            byteStart: label.byteStart,
            byteEnd: label.byteEnd,
            lineStart: label.lineStart,
            lineEnd: label.lineEnd,
            column: label.column,
            text: label.text,
            macroName: label.macroName
        )
    }

    static func stored(_ note: DiagnosticNote) -> StoredNote {
        StoredNote(level: stored(note.level), message: note.message, labels: note.labels.map(stored))
    }

    static func stored(_ level: DiagnosticLevel) -> StoredNoteLevel {
        switch level {
        case .error:
            .error
        case .warning:
            .warning
        case .note:
            .note
        case .help:
            .help
        }
    }

    static func stored(_ fix: DiagnosticFix) -> StoredFix {
        StoredFix(title: fix.title, edits: fix.edits.map(stored))
    }

    static func stored(_ edit: TextEdit) -> StoredEdit {
        StoredEdit(
            startByte: edit.startByte,
            endByte: edit.endByte,
            text: edit.text,
            caretByte: edit.caretByte
        )
    }

    static func ffi(_ fix: StoredFix) -> DiagnosticFix {
        DiagnosticFix(title: fix.title, edits: fix.edits.map(ffi))
    }

    static func ffi(_ edit: StoredEdit) -> TextEdit {
        TextEdit(
            startByte: edit.startByte,
            endByte: edit.endByte,
            text: edit.text,
            caretByte: edit.caretByte
        )
    }

    static func ffi(_ item: StoredDiagnostic) -> Diagnostic {
        Diagnostic(
            level: item.level == .error ? .error : .warning,
            message: item.message,
            code: item.code,
            primary: ffi(item.primary),
            secondary: item.secondary.map(ffi),
            notes: item.notes.map(ffi),
            fixes: item.fixes.map(ffi)
        )
    }

    static func ffi(_ label: StoredLabel) -> DiagnosticLabel {
        DiagnosticLabel(
            path: label.path,
            byteStart: label.byteStart,
            byteEnd: label.byteEnd,
            lineStart: label.lineStart,
            lineEnd: label.lineEnd,
            column: label.column,
            text: label.text,
            macroName: label.macroName
        )
    }

    static func ffi(_ note: StoredNote) -> DiagnosticNote {
        DiagnosticNote(level: ffi(note.level), message: note.message, labels: note.labels.map(ffi))
    }

    static func ffi(_ level: StoredNoteLevel) -> DiagnosticLevel {
        switch level {
        case .error:
            .error
        case .warning:
            .warning
        case .note:
            .note
        case .help:
            .help
        }
    }

    static func lastLine(_ text: String) -> String? {
        text.split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
