import CoreGraphics
import Foundation

private struct PlacedChip {
    var line: Int
    var measured: OverlayMeasuredChip
}

private struct LabelSite {
    var line: Int
    var offset: Int
    var anchor: Int
    var start: Int
    var end: Int
}

enum OverlayModel {
    static func place(
        _ diagnostic: StoredDiagnostic,
        lineAt: (Int) -> Int,
        lineStart: (Int) -> Int,
        utf16: (Int) -> Int,
        visibleLine: (Int) -> Int = { $0 },
        x: (Int) -> CGFloat,
        width: (String) -> CGFloat
    ) -> OverlayLayout {
        let primary = site(diagnostic.primary, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine)
        let placed = chips(
            diagnostic,
            primary: primary,
            lineAt: lineAt,
            lineStart: lineStart,
            utf16: utf16,
            visibleLine: visibleLine,
            x: x
        )
        let rows = Dictionary(grouping: placed, by: \.line).mapValues { OverlayPack.rows($0.map(\.measured), width: width) }
        return OverlayLayout(
            rows: rows,
            numbers: numbers(diagnostic, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine),
            brackets: brackets(diagnostic, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine),
            notes: noteRows(diagnostic, lineAt: lineAt, utf16: utf16),
            primaryLine: primary.line,
            showsFix: !diagnostic.fixes.isEmpty
        )
    }

    private static func chips(
        _ diagnostic: StoredDiagnostic,
        primary: LabelSite,
        lineAt: (Int) -> Int,
        lineStart: (Int) -> Int,
        utf16: (Int) -> Int,
        visibleLine: (Int) -> Int,
        x: (Int) -> CGFloat
    ) -> [PlacedChip] {
        var labels: [(StoredLabel, OverlayChipKind)] = [(diagnostic.primary, .primary)]
        labels += diagnostic.secondary.map { ($0, .secondary) }
        labels += diagnostic.notes.flatMap { note in note.labels.map { ($0, .note) } }
        return labels.flatMap { label, kind in
            chip(label, kind: kind, owner: diagnostic.path, primary: primary, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine, x: x)
        }
    }

    private static func chip(
        _ label: StoredLabel,
        kind: OverlayChipKind,
        owner: String,
        primary: LabelSite,
        lineAt: (Int) -> Int,
        lineStart: (Int) -> Int,
        utf16: (Int) -> Int,
        visibleLine: (Int) -> Int,
        x: (Int) -> CGFloat
    ) -> [PlacedChip] {
        if label.path != owner {
            let anchor = lineStart(primary.line)
            let chip = OverlayChip(offset: 0, text: externalText(label), kind: .external)
            return [PlacedChip(line: primary.line, measured: OverlayMeasuredChip(chip: chip, x: x(anchor)))]
        }
        guard let text = chipText(label) else {
            return []
        }
        let here = site(label, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine)
        let chip = OverlayChip(offset: here.offset, text: text, kind: kind)
        return [PlacedChip(line: here.line, measured: OverlayMeasuredChip(chip: chip, x: x(here.anchor)))]
    }

    private static func numbers(
        _ diagnostic: StoredDiagnostic,
        lineAt: (Int) -> Int,
        lineStart: (Int) -> Int,
        utf16: (Int) -> Int,
        visibleLine: (Int) -> Int
    ) -> [OverlayGutterMark] {
        var spans: [(StoredLabel, OverlayChipKind)] = [(diagnostic.primary, .primary)]
        spans += diagnostic.secondary.filter { $0.path == diagnostic.path }.map { ($0, .secondary) }
        guard spans.count > 1 else {
            return []
        }
        let ordered = spans.sorted { $0.0.byteStart < $1.0.byteStart || ($0.0.byteStart == $1.0.byteStart && $0.0.byteEnd < $1.0.byteEnd) }
        return ordered.enumerated().map { index, item in
            let here = site(item.0, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine)
            return OverlayGutterMark(line: here.line, number: index + 1, kind: item.1)
        }
    }

    private static func brackets(
        _ diagnostic: StoredDiagnostic,
        lineAt: (Int) -> Int,
        lineStart: (Int) -> Int,
        utf16: (Int) -> Int,
        visibleLine: (Int) -> Int
    ) -> [OverlayBracket] {
        var spans: [(StoredLabel, OverlayChipKind)] = [(diagnostic.primary, .primary)]
        spans += diagnostic.secondary.filter { $0.path == diagnostic.path }.map { ($0, .secondary) }
        for note in diagnostic.notes {
            spans += note.labels.filter { $0.path == diagnostic.path }.map { ($0, .note) }
        }
        return spans.compactMap { label, kind in
            let here = site(label, lineAt: lineAt, lineStart: lineStart, utf16: utf16, visibleLine: visibleLine)
            let start = visibleLine(here.start)
            let end = visibleLine(here.end)
            guard end > start else {
                return nil
            }
            return OverlayBracket(start: start, end: end, kind: kind)
        }
    }

    private static func noteRows(_ diagnostic: StoredDiagnostic, lineAt: (Int) -> Int, utf16: (Int) -> Int) -> [OverlayNoteRow] {
        let fix = diagnostic.fixes.first?.title
        var usedFix = false
        return diagnostic.notes.map { note in
            let jump = note.labels.first { $0.path == diagnostic.path }.map { lineAt(utf16(Int($0.byteStart))) }
            var title: String?
            if note.level == .help, let fix, !usedFix {
                title = fix
                usedFix = true
            }
            return OverlayNoteRow(level: note.level, message: note.message, jumpLine: jump, fixTitle: title)
        }
    }

    private static func site(
        _ label: StoredLabel,
        lineAt: (Int) -> Int,
        lineStart: (Int) -> Int,
        utf16: (Int) -> Int,
        visibleLine: (Int) -> Int
    ) -> LabelSite {
        let startUTF = utf16(Int(label.byteStart))
        let endUTF = utf16(Int(label.byteEnd))
        let startLine = lineAt(startUTF)
        let endLine = endUTF > startUTF ? lineAt(endUTF - 1) : startLine
        let raw = startLine == endLine ? startLine : endLine
        let anchor = startLine == endLine ? startUTF : lineStart(endLine)
        let line = visibleLine(raw)
        let origin = lineStart(line)
        let offset = line == raw ? max(0, anchor - origin) : 0
        let measured = line == raw ? anchor : origin
        return LabelSite(line: line, offset: offset, anchor: measured, start: startLine, end: endLine)
    }

    private static func chipText(_ label: StoredLabel) -> String? {
        guard let text = label.text, !text.isEmpty else {
            return nil
        }
        guard let macro = label.macroName else {
            return text
        }
        return text + " in " + macro
    }

    private static func externalText(_ label: StoredLabel) -> String {
        let file = URL(fileURLWithPath: label.path).lastPathComponent
        let place = "↗ \(file):\(label.lineStart)"
        guard let text = chipText(label) else {
            return place
        }
        return text + " " + place
    }
}
