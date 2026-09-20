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
            path: diag.path,
            byteStart: diag.byteStart,
            byteEnd: diag.byteEnd,
            line: diag.line,
            column: diag.column,
            level: level,
            message: diag.message,
            code: diag.code,
            fixes: diag.fixes.map(stored)
        )
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
            path: item.path,
            byteStart: item.byteStart,
            byteEnd: item.byteEnd,
            line: item.line,
            column: item.column,
            level: item.level == .error ? .error : .warning,
            message: item.message,
            code: item.code,
            fixes: item.fixes.map(ffi)
        )
    }

    static func lastLine(_ text: String) -> String? {
        text.split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
