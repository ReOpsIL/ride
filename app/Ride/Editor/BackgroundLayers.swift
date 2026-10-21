import AppKit

enum BackgroundLayer: Int, CaseIterable {
    case caretLine
    case markedLine
    case bracket

    func color(_ editor: EditorColors) -> NSColor {
        switch self {
        case .caretLine: return editor.currentLine
        case .markedLine: return editor.markedLine
        case .bracket: return editor.bracketMatch
        }
    }
}

struct BackgroundPaint: Equatable {
    var layer: BackgroundLayer
    var range: NSRange
}

struct BackgroundLayers {
    private var layers: [BackgroundLayer: [NSRange]] = [:]

    mutating func set(_ layer: BackgroundLayer, ranges: [NSRange]) {
        layers[layer] = ranges.isEmpty ? nil : ranges
    }

    func ranges(_ layer: BackgroundLayer) -> [NSRange] {
        layers[layer] ?? []
    }

    func stacked() -> [BackgroundPaint] {
        BackgroundLayer.allCases.flatMap { layer in
            ranges(layer).map { BackgroundPaint(layer: layer, range: $0) }
        }
    }
}
