import AppKit

extension RideTextView {
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
