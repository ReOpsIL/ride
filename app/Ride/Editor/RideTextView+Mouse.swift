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
        HoverController.shared.mouseMoved(view: self, event: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        HoverController.shared.hide()
    }

    override func mouseDown(with event: NSEvent) {
        HoverController.shared.hide()
        if event.modifierFlags.contains(.command), let go = hooks.goToDefinition {
            let point = convert(event.locationInWindow, from: nil)
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
