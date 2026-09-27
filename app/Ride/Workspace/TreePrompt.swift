import AppKit

enum TreePrompt {
    static func name(title: String, defaultName: String) -> String? {
        if let scripted = DialogScript.next(ScriptedName.self) {
            return scripted.name
        }
        let field = NSTextField(string: defaultName)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        return run(title: title, accessory: field, field: field)
    }

    static func newFileName(kind: ProjectKind?) -> String? {
        if let scripted = DialogScript.next(ScriptedName.self) {
            return scripted.name
        }
        let picker = LanguageNameField(language: NewFilePrompt.language(for: NewFileKind(kind)))
        return withExtendedLifetime(picker) { run(title: "New File", accessory: picker.accessory, field: picker.field) }
    }

    private static func run(title: String, accessory: NSView, field: NSTextField) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

extension NewFileKind {
    init(_ kind: ProjectKind?) {
        switch kind {
        case .cMake: self = .cmake
        case .make: self = .make
        case .cargo: self = .cargo
        default: self = .other
        }
    }
}
