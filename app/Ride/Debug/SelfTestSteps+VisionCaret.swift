import AppKit

extension SelfTestSteps {
    static func visionCaret(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "vision caret rect", run: {
            e.activate()
            guard let view = e.view, let start = VisionCaretProbe.firstVisionLine(in: view) else {
                return
            }
            view.setSelectedRange(NSRange(location: start + 4, length: 0))
        }, check: {
            guard let view = e.view, let band = VisionCaretProbe.textBand(in: view) else {
                return "no vision line under the caret"
            }
            let caret = SelfTestPixels.rect(of: view.selectedRange(), in: view)
            return e.expect(
                abs(caret.minY - band.minY) < 1 && abs(caret.maxY - band.maxY) < 1,
                "caret \(caret) text line \(band)"
            )
        })
    }
}

enum VisionCaretProbe {
    static func firstVisionLine(in view: RideTextView) -> Int? {
        guard let tlm = view.textLayoutManager, let storage = view.textContentStorage else {
            return nil
        }
        var start: Int?
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: [.ensuresLayout]) { fragment in
            guard fragment is VisionFragment else {
                return true
            }
            start = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
            return false
        }
        return start
    }

    static func textBand(in view: RideTextView) -> CGRect? {
        guard let tlm = view.textLayoutManager, let range = view.textRange(utf16: view.selectedRange()),
              let fragment = tlm.textLayoutFragment(for: range.location) as? VisionFragment,
              let line = fragment.textLineFragments.first else {
            return nil
        }
        let origin = fragment.layoutFragmentFrame.origin
        return line.typographicBounds.offsetBy(
            dx: origin.x + view.textContainerOrigin.x,
            dy: origin.y + view.textContainerOrigin.y
        )
    }
}
