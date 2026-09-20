import AppKit

extension RideTextView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = hoverArea {
            removeTrackingArea(old)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if hooks.binding?()?.state.prefs.hoverDocs != false {
            HoverController.shared.mouseMoved(view: self, event: event)
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        HoverController.shared.hide()
    }

    override func mouseDown(with event: NSEvent) {
        HoverController.shared.hide()
        EditorPanes.shared.host(for: self)?.hideUnpinnedDocs()
        let point = convert(event.locationInWindow, from: nil)
        if let utf16 = visionHit(at: point) {
            placeCaretOnVisionItem(at: utf16)
            hooks.binding?()?.state.findUsages()
            return
        }
        if event.modifierFlags.contains(.command), let go = hooks.goToDefinition {
            let index = characterIndexForInsertion(at: point)
            setSelectedRange(NSRange(location: index, length: 0))
            go(index)
            return
        }
        super.mouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        HoverController.shared.hide()
        super.scrollWheel(with: event)
    }
}
