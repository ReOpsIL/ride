import AppKit

enum SelfTestGutter {
    static func host(_ e: SelfTestEditor) -> EditorHostView? {
        e.view?.enclosingScrollView?.superview as? EditorHostView
    }

    static func click(_ e: SelfTestEditor, line: Int, right: Bool = false) -> Bool {
        guard let view = e.view, let gutter = host(e)?.gutter, let range = view.lineRange(line) else {
            return false
        }
        guard let row = row(gutter, line: line) else {
            view.scrollRangeToVisible(range)
            return false
        }
        let x = GutterView.markerColumn + GutterView.glyphColumn + GutterView.breakpointColumn / 2
        let point = gutter.convert(NSPoint(x: x, y: row.midY), to: nil)
        guard let event = NSEvent.mouseEvent(
            with: right ? .rightMouseDown : .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: gutter.window?.windowNumber ?? 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else {
            return false
        }
        if right {
            gutter.rightMouseDown(with: event)
        } else {
            gutter.mouseDown(with: event)
        }
        return true
    }

    private static func row(_ gutter: GutterView, line: Int) -> NSRect? {
        var found: NSRect?
        gutter.enumerateVisibleLines { number, rect in
            if number == line {
                found = rect
            }
            return found == nil
        }
        return found.flatMap { gutter.bounds.intersects($0) ? $0 : nil }
    }
}

enum SelfTestSheet {
    static func answer(_ window: NSWindow?, values: [String], button: String) -> Bool {
        guard let content = window?.attachedSheet?.contentView else {
            return false
        }
        let fields = editableFields(in: content)
        guard fields.count >= values.count else {
            return false
        }
        zip(fields, values).forEach { field, value in field.stringValue = value }
        return SelfTestViews.click(in: content) { $0.title == button }
    }

    private static func editableFields(in root: NSView) -> [NSTextField] {
        let own = (root as? NSTextField).map { $0.isEditable ? [$0] : [] } ?? []
        return own + root.subviews.flatMap(editableFields(in:))
    }
}

enum SelfTestShortcut {
    @discardableResult
    static func press(_ path: String, in window: NSWindow?) -> Bool {
        guard let keys = Shortcuts.keys(for: path), let combo = KeyCombo(glyphs: keys), let window,
              let event = SelfTestKeys.event(combo, window: window), SelfTestMenu.isEnabled(path),
              let item = SelfTestMenu.item(path), KeyCombo(item: item) == combo
        else {
            return false
        }
        return item.menu?.performKeyEquivalent(with: event) ?? false
    }
}

enum SelfTestMarkedLine {
    static func isTinted(_ view: RideTextView?, line: Int) -> Bool {
        guard let view, let tlm = view.textLayoutManager, let range = view.lineRange(line), range.length > 0,
              let lineRange = view.textRange(utf16: range)
        else {
            return false
        }
        var tinted = false
        tlm.enumerateRenderingAttributes(from: lineRange.location, reverse: false) { _, attributes, found in
            guard found.location.compare(lineRange.endLocation) == .orderedAscending else {
                return false
            }
            tinted = attributes[.backgroundColor] != nil && found.endLocation.compare(lineRange.location) == .orderedDescending
            return !tinted
        }
        return tinted
    }
}
