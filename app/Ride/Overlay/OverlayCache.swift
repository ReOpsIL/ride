import Foundation

final class OverlayCache {
    var drawn: [OverlayDrawn] = []
    var stamps: [Int: String] = [:]
    var numbers: [Int: [OverlayGutterNumber]] = [:]
    var brackets: [OverlayGutterBracket] = []
    var spanMarks: [OverlaySpanMark] = []
    var painted: [NSRange] = []
    var utf16 = Utf16Map("")
    var utf16Generation = -1

    var showsOverlay: Bool {
        !drawn.isEmpty || !painted.isEmpty
    }
}

struct OverlaySpanMark: Equatable {
    var range: NSRange
    var note: Bool
}

struct OverlayDrawn {
    var layout: OverlayLayout
    var level: ProblemLevel
}

struct OverlayGutterNumber: Equatable {
    var mark: OverlayGutterMark
    var warning: Bool
}

struct OverlayGutterBracket: Equatable {
    var bracket: OverlayBracket
    var warning: Bool
}

struct OverlayGutterToken: Equatable {
    var numbers: [Int: [OverlayGutterNumber]]
    var brackets: [OverlayGutterBracket]
}
