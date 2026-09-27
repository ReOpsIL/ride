import AppKit

extension SelfTestSteps {
    static func prefDisplaySteps(state: AppState, e: SelfTestEditor, bind: PreferenceBindings, p: PrefScratch) -> [SelfTestStep] {
        let editorWidth = { e.view?.enclosingScrollView?.frame.width ?? 0 }
        let gutterWidth = { EditorPanes.shared.focused?.gutter.bounds.width ?? 0 }
        let mainY = { () -> CGFloat in
            guard let view = e.view else {
                return 0
            }
            let range = (view.string as NSString).range(of: "fn main()")
            return range.location == NSNotFound ? 0 : SelfTestPixels.rect(of: range, in: view).minY
        }
        let line = { (e.lines.firstIndex { $0.hasPrefix("    counter.record(") } ?? 9) + 1 }
        let guideShades = { e.view.map { SelfTestPixels.shades($0, in: SelfTestPixels.leadingSpaces(line: line(), from: 0, count: 1, e: e)) } ?? 0 }
        let spaceShades = { e.view.map { SelfTestPixels.shades($0, in: SelfTestPixels.leadingSpaces(line: line(), from: 1, count: 2, e: e)) } ?? 0 }
        return [
            toggleStep("pref outline panel off", bind, \.outlinePanel, false, before: { p.width = editorWidth() }) {
                e.expect(editorWidth() > p.width + 100 && !state.menu.outlinePanel, "width \(p.width) -> \(editorWidth())")
            },
            toggleStep("pref outline panel on", bind, \.outlinePanel, true) {
                e.expect(abs(editorWidth() - p.width) < 2 && state.menu.outlinePanel, "width \(editorWidth()) expected \(p.width)")
            },
            toggleStep("pref line numbers off", bind, \.lineNumbers, false, before: { p.width = gutterWidth() }) {
                e.expect(gutterWidth() < p.width && !state.menu.lineNumbers, "gutter \(p.width) -> \(gutterWidth())")
            },
            toggleStep("pref line numbers on", bind, \.lineNumbers, true) {
                e.expect(gutterWidth() == p.width, "gutter \(gutterWidth()) expected \(p.width)")
            },
            toggleStep("pref indent guides off", bind, \.indentGuides, false, before: { e.caret(line: 1); p.shades = guideShades() }) {
                e.expect(guideShades() < p.shades && e.view?.showIndentGuides == false, "shades \(p.shades) -> \(guideShades())")
            },
            toggleStep("pref indent guides on", bind, \.indentGuides, true) {
                e.expect(guideShades() == p.shades, "shades \(guideShades()) expected \(p.shades)")
            },
            toggleStep("pref visible whitespace on", bind, \.visibleWhitespace, true, before: { e.caret(line: 1); p.shades = spaceShades() }) {
                e.expect(spaceShades() > p.shades && state.menu.visibleWhitespace, "shades \(p.shades) -> \(spaceShades())")
            },
            toggleStep("pref visible whitespace off", bind, \.visibleWhitespace, false) {
                e.expect(spaceShades() == p.shades, "shades \(spaceShades()) expected \(p.shades)")
            },
            toggleStep("pref code vision off", bind, \.codeVision, false, before: { p.y = mainY(); p.shades = e.view?.visionLines().count ?? 0 }) {
                e.expect(p.shades > 0 && e.view?.visionLines().isEmpty == true && mainY() < p.y - 2, "labels \(p.shades) fn main y \(p.y) -> \(mainY())")
            },
            toggleStep("pref code vision on", bind, \.codeVision, true, wait: 1.5) {
                e.expect(e.view?.visionLines().count == p.shades && abs(mainY() - p.y) < 1, "fn main y \(mainY()) expected \(p.y)")
            },
            toggleStep("pref soft wrap off", bind, \.softWrap, false) {
                e.expect(e.view?.textContainer?.widthTracksTextView == false && e.view?.enclosingScrollView?.hasHorizontalScroller == true, "still wrapping")
            },
            toggleStep("pref soft wrap on", bind, \.softWrap, true) {
                e.expect(e.view?.textContainer?.widthTracksTextView == true, "not wrapping")
            },
        ]
    }

    static func toggleStep(
        _ name: String,
        _ bind: PreferenceBindings,
        _ key: WritableKeyPath<Preferences, Bool>,
        _ value: Bool,
        wait: Double = 0.6,
        before: @escaping () -> Void = {},
        check: @escaping () -> String?
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: wait, run: {
            before()
            bind.bool(key).wrappedValue = value
        }, check: check)
    }
}
