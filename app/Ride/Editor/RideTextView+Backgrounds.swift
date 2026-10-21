import AppKit

extension RideTextView {
    func setBackground(_ layer: BackgroundLayer, ranges: [NSRange]) {
        backgrounds.set(layer, ranges: ranges)
        repaintBackgrounds()
    }

    func repaintBackgrounds() {
        guard let tlm = textLayoutManager else {
            return
        }
        var dirty = paintedBackgrounds.compactMap(lineBand)
        for range in paintedBackgrounds {
            if let tr = textRange(utf16: range) {
                tlm.removeRenderingAttribute(.backgroundColor, for: tr)
            }
        }
        paintedBackgrounds = []
        let editor = ThemeStore.shared.editor
        let length = (string as NSString).length
        for paint in backgrounds.stacked() {
            let clamped = RangeShift.clamp(paint.range, length: length)
            guard clamped.length > 0, let tr = textRange(utf16: clamped) else {
                continue
            }
            tlm.addRenderingAttribute(.backgroundColor, value: paint.layer.color(editor), for: tr)
            paintedBackgrounds.append(clamped)
            dirty += lineBand(clamped).map { [$0] } ?? []
        }
        redisplay(dirty, in: self)
    }

    private func redisplay(_ rects: [NSRect], in view: NSView) {
        for rect in rects {
            let local = view.convert(rect, from: self)
            if local.intersects(view.bounds) {
                view.setNeedsDisplay(local)
            }
        }
        for subview in view.subviews {
            redisplay(rects, in: subview)
        }
    }
}
