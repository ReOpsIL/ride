import AppKit

final class PopupShiftScratch {
    var caretBefore = NSRect.zero
    var caretAfter = NSRect.zero
    var panel = NSRect.zero
    var expected = NSRect.zero
    var visible = false
}

extension SelfTestSteps {
    static func popupFollowsLayout(e: SelfTestEditor) -> [SelfTestStep] {
        let scratch = PopupShiftScratch()
        return [openCompletionUnderLabels(e: e), completionFollowsVisionToggle(e: e, scratch: scratch)]
    }

    private static func openCompletionUnderLabels(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "completion opens under vision labels", until: { CompletionSession.shared.isVisible }, timeout: 8, run: {
            e.activate()
            e.place(on: "impl Recorder")
            e.view.map { $0.setSelectedRange(NSRange(location: $0.selectedRange().location + 10, length: 0)) }
            e.view?.scroll(.zero)
            SelfTestKeys.post("⌥esc", window: SelfTestKeys.mainWindow)
        }, check: {
            guard let view = e.view else {
                return "editor missing"
            }
            return e.expect(CompletionSession.shared.isVisible && !view.visionLines().isEmpty, "visible \(CompletionSession.shared.isVisible) labels \(view.visionLines().count)")
        })
    }

    private static func completionFollowsVisionToggle(e: SelfTestEditor, scratch: PopupShiftScratch) -> SelfTestStep {
        SelfTestStep(name: "completion follows vision relayout", run: {
            guard let view = e.view else {
                return
            }
            scratch.caretBefore = CompletionPlacement.caretRect(in: view)
            view.applyCodeVision(false)
            scratch.caretAfter = CompletionPlacement.caretRect(in: view)
            scratch.panel = CompletionSession.shared.popup.panel.frame
            scratch.expected = CompletionPlacement.frame(caret: scratch.caretAfter, screen: CompletionPlacement.screen(for: view), size: scratch.panel.size)
            scratch.visible = CompletionSession.shared.isVisible
            CompletionSession.shared.hide()
            view.applyCodeVision(true)
        }, check: {
            e.expect(
                scratch.visible && scratch.caretAfter.minY != scratch.caretBefore.minY && abs(scratch.panel.minY - scratch.expected.minY) < 1,
                "visible \(scratch.visible) caret \(scratch.caretBefore.minY) -> \(scratch.caretAfter.minY) panel \(scratch.panel.minY) expected \(scratch.expected.minY)"
            )
        })
    }
}
