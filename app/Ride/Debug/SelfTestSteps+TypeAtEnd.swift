import AppKit

extension SelfTestSteps {
    static func typeAtEnd(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let keys = Array("\n\n\nlet tail = 1;\n\n\n")
        let pace = 0.25
        let probe = TypeAtEndProbe()
        var watch: ViewportWatch?
        return SelfTestStep(name: "type at end", wait: Double(keys.count) * pace + 1.5, run: {
            guard let view = e.view else {
                return
            }
            state.showProblems = true
            watch = ViewportWatch(view: view)
            let end = (view.string as NSString).length
            view.setSelectedRange(NSRange(location: end, length: 0))
            view.insertText(String(repeating: "// filler\n", count: 60), replacementRange: NSRange(location: NSNotFound, length: 0))
            view.scrollRangeToVisible(view.selectedRange())
            for (i, key) in keys.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * pace) {
                    if key == "\n" {
                        view.insertNewline(nil)
                    } else {
                        view.insertText(String(key), replacementRange: NSRange(location: NSNotFound, length: 0))
                    }
                    watch?.label = "key \(i)"
                    probe.watch(view, key: i, for: pace - 0.05)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(keys.count) * pace) {
                probe.countsChanged(view)
            }
        }, check: {
            let drawn = watch?.failures ?? ["viewport watch not attached"]
            return e.expect(drawn.isEmpty && probe.caretFailures.isEmpty, (drawn + probe.caretFailures).prefix(6).joined(separator: "; ") + " (layouts \(watch?.layouts ?? 0))")
        })
    }
}

final class TypeAtEndProbe {
    private(set) var caretFailures: [String] = []

    func countsChanged(_ view: RideTextView) {
        guard let document = view.hooks.binding?()?.document, let tlm = view.textLayoutManager else {
            return
        }
        let before = view.visionLines()
        document.visionCounts = document.visionCounts.mapValues { $0 + 1 }
        view.refreshVision(from: before)
        var bottom: CGFloat = 0
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.endLocation, options: [.reverse, .ensuresLayout]) { fragment in
            bottom = fragment.layoutFragmentFrame.maxY
            return false
        }
        if view.frame.height + 0.5 < bottom {
            caretFailures.append("after count change the view is \(Int(view.frame.height)) tall, last line ends at \(Int(bottom))")
        }
    }

    func watch(_ view: RideTextView, key: Int, for duration: Double) {
        for tick in stride(from: 0.01, through: duration, by: 0.01) {
            DispatchQueue.main.asyncAfter(deadline: .now() + tick) { [weak self] in
                self?.sample(view, key: key, tick: tick)
            }
        }
    }

    private func sample(_ view: RideTextView, key: Int, tick: Double) {
        let caret = caretRect(view)
        let visible = view.visibleRect
        if caret.maxY > visible.maxY + 0.5 {
            caretFailures.append("key \(key) +\(Int(tick * 1000))ms caret below view (\(Int(caret.maxY)) > \(Int(visible.maxY)))")
        }
    }

    private func caretRect(_ view: RideTextView) -> CGRect {
        guard let window = view.window else {
            return .zero
        }
        let screen = view.firstRect(forCharacterRange: view.selectedRange(), actualRange: nil)
        return view.convert(window.convertFromScreen(screen), from: nil)
    }
}
