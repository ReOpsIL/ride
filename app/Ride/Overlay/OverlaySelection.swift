import Foundation

enum OverlaySelection {
    static func active(
        caret: Int,
        mode: DiagnosticOverlayMode,
        diagnostics: [StoredDiagnostic],
        lineAt: (Int) -> Int,
        range: (StoredLabel) -> NSRange
    ) -> [StoredDiagnostic] {
        switch mode {
        case .off:
            return []
        case .all:
            return diagnostics
        case .caret:
            let hits = diagnostics.enumerated().filter { covers($0.element, caret: caret, lineAt: lineAt, range: range) }
            guard let best = hits.min(by: { precedes($0, $1, range: range) }) else {
                return []
            }
            return [best.element]
        }
    }

    private static func covers(
        _ diagnostic: StoredDiagnostic,
        caret: Int,
        lineAt: (Int) -> Int,
        range: (StoredLabel) -> NSRange
    ) -> Bool {
        let labels = [diagnostic.primary] + diagnostic.secondary.filter { $0.path == diagnostic.path }
        if labels.contains(where: { holds(caret, range($0)) }) {
            return true
        }
        let span = range(diagnostic.primary)
        let caretLine = lineAt(caret)
        let start = lineAt(span.location)
        let end = lineAt(span.length == 0 ? span.location : NSMaxRange(span) - 1)
        return caretLine >= start && caretLine <= end
    }

    private static func holds(_ caret: Int, _ span: NSRange) -> Bool {
        if span.length == 0 {
            return caret == span.location
        }
        return caret >= span.location && caret <= NSMaxRange(span)
    }

    private static func precedes(
        _ lhs: (offset: Int, element: StoredDiagnostic),
        _ rhs: (offset: Int, element: StoredDiagnostic),
        range: (StoredLabel) -> NSRange
    ) -> Bool {
        let left = rank(lhs.element, range: range)
        let right = rank(rhs.element, range: range)
        if left != right {
            return left < right
        }
        return lhs.offset < rhs.offset
    }

    private static func rank(_ diagnostic: StoredDiagnostic, range: (StoredLabel) -> NSRange) -> (Int, Int, Int) {
        let span = range(diagnostic.primary)
        return (diagnostic.level == .error ? 0 : 1, span.length, span.location)
    }
}
