import CoreGraphics
import Foundation

enum OverlayChipKind: Equatable {
    case primary
    case secondary
    case note
    case external
}

struct OverlayChip: Equatable {
    var offset: Int
    var text: String
    var kind: OverlayChipKind
}

struct OverlayChipRow: Equatable {
    var chips: [OverlayChip]
}

struct OverlayNoteRow: Equatable {
    var level: StoredNoteLevel
    var message: String
    var jumpLine: Int?
    var fixTitle: String?
}

struct OverlayGutterMark: Equatable {
    var line: Int
    var number: Int
    var kind: OverlayChipKind
}

struct OverlayBracket: Equatable {
    var start: Int
    var end: Int
    var kind: OverlayChipKind
}

struct OverlayLayout: Equatable {
    var rows: [Int: [OverlayChipRow]]
    var numbers: [OverlayGutterMark]
    var brackets: [OverlayBracket]
    var notes: [OverlayNoteRow]
    var primaryLine: Int
    var showsFix: Bool
}

struct OverlayMeasuredChip {
    var chip: OverlayChip
    var x: CGFloat
}

enum OverlayPack {
    static func rows(_ chips: [OverlayMeasuredChip], width: (String) -> CGFloat) -> [OverlayChipRow] {
        var packed: [[OverlayMeasuredChip]] = []
        for chip in chips.sorted(by: { $0.x < $1.x }) {
            if let index = packed.firstIndex(where: { fits(chip, in: $0, width: width) }) {
                packed[index].append(chip)
            } else {
                packed.append([chip])
            }
        }
        for index in packed.indices {
            packed[index].sort { $0.x < $1.x }
        }
        packed.sort { ($0.first?.x ?? 0) < ($1.first?.x ?? 0) }
        return packed.map { OverlayChipRow(chips: $0.map(\.chip)) }
    }

    private static func fits(_ chip: OverlayMeasuredChip, in row: [OverlayMeasuredChip], width: (String) -> CGFloat) -> Bool {
        let start = chip.x
        let end = start + width(chip.chip.text)
        return row.allSatisfy { placed in
            let placedEnd = placed.x + width(placed.chip.text)
            return end <= placed.x || start >= placedEnd
        }
    }
}
