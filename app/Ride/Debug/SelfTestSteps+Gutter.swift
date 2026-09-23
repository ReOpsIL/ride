import AppKit

extension SelfTestSteps {
    static func gutterSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            gutterNumbers(e: e, name: "gutter numbers", run: { e.caret(line: 1) }, shown: true),
            gutterNumbers(e: e, name: "line numbers hidden", run: { state.prefs.lineNumbers = false }, shown: false),
            gutterNumbers(e: e, name: "line numbers shown", run: { state.prefs.lineNumbers = true }, shown: true),
        ]
    }

    private static func gutterNumbers(e: SelfTestEditor, name: String, run: @escaping () -> Void, shown: Bool) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.3, run: run, check: {
            guard let gutter = (e.view?.enclosingScrollView?.superview as? EditorHostView)?.gutter else {
                return e.expect(false, "gutter missing")
            }
            let shades = numberColumnShades(gutter)
            let narrow = gutter.bounds.width <= GutterView.width(digits: 1, numbers: false) + 0.5
            return e.expect(
                shown ? shades > 3 && !narrow : shades == 1 && narrow,
                "numbers \(shown): \(shades) shades, width \(gutter.bounds.width)"
            )
        })
    }

    private static func numberColumnShades(_ gutter: GutterView) -> Int {
        guard let rep = gutter.bitmapImageRepForCachingDisplay(in: gutter.bounds) else {
            return 0
        }
        gutter.cacheDisplay(in: gutter.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / max(gutter.bounds.width, 1)
        let left = Int((GutterView.markerColumn + GutterView.glyphColumn) * scale)
        let right = rep.pixelsWide - Int(2 * scale)
        var shades = Set<UInt32>()
        for y in stride(from: 0, to: rep.pixelsHigh, by: 1) {
            for x in stride(from: left, to: right, by: 1) {
                var pixel = [Int](repeating: 0, count: 4)
                rep.getPixel(&pixel, atX: x, y: y)
                shades.insert(UInt32(pixel[0] << 16 | pixel[1] << 8 | pixel[2]))
            }
        }
        return shades.count
    }
}
