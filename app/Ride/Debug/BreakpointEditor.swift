import AppKit

enum BreakpointEditor {
    static func run(_ mark: BreakpointMark, path: String) -> BreakpointMark? {
        guard !DemoLaunch.isDemo else {
            return nil
        }
        let condition = field(mark.condition, placeholder: "Condition, e.g. i == 3")
        let hits = field(mark.hitCondition, placeholder: "Hit count, e.g. >5")
        let alert = NSAlert()
        alert.messageText = "Breakpoint at line \(mark.line)"
        alert.informativeText = URL(fileURLWithPath: path).lastPathComponent
        alert.accessoryView = stack([condition, hits])
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = condition
        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        var edited = mark
        edited.condition = condition.stringValue
        edited.hitCondition = hits.stringValue
        return edited
    }

    private static func field(_ value: String?, placeholder: String) -> NSTextField {
        let field = NSTextField(string: value ?? "")
        field.placeholderString = placeholder
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 280).isActive = true
        return field
    }

    private static func stack(_ fields: [NSTextField]) -> NSView {
        let stack = NSStackView(views: fields)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 280, height: 60)
        return stack
    }
}
