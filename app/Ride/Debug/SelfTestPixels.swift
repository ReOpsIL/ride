import AppKit

enum SelfTestPixels {
    static func shades(_ view: NSView, in rect: NSRect) -> Int {
        let area = rect.intersection(view.bounds)
        guard !area.isEmpty, let rep = view.bitmapImageRepForCachingDisplay(in: area) else {
            return 0
        }
        view.cacheDisplay(in: area, to: rep)
        var seen = Set<Int>()
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                seen.insert(Int(color.redComponent * 31) << 10 | Int(color.greenComponent * 31) << 5 | Int(color.blueComponent * 31))
            }
        }
        return seen.count
    }

    static func rect(of range: NSRange, in view: RideTextView) -> NSRect {
        guard let window = view.window else {
            return .zero
        }
        let screen = view.firstRect(forCharacterRange: range, actualRange: nil)
        return view.convert(window.convertFromScreen(screen), from: nil)
    }

    static func leadingSpaces(line: Int, from: Int, count: Int, e: SelfTestEditor) -> NSRect {
        guard let view = e.view else {
            return .zero
        }
        let start = e.lineRange(line).location
        return rect(of: NSRange(location: start + from, length: count), in: view)
    }
}
