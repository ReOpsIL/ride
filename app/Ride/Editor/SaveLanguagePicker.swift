import AppKit

final class SaveLanguagePicker: NSObject {
    private weak var panel: NSSavePanel?
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let languages = NewFilePrompt.languages

    init(panel: NSSavePanel, initial: BufferLanguage) {
        self.panel = panel
        super.init()
        for language in languages {
            popup.addItem(withTitle: language.title ?? language.fileExtension)
        }
        popup.selectItem(at: languages.firstIndex(of: initial) ?? 0)
        popup.target = self
        popup.action = #selector(changed)
        panel.accessoryView = accessory()
    }

    private func accessory() -> NSView {
        let label = NSTextField(labelWithString: "Language:")
        let stack = NSStackView(views: [label, popup])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        stack.setFrameSize(stack.fittingSize)
        return stack
    }

    @objc private func changed() {
        guard let panel else {
            return
        }
        let language = languages[max(0, popup.indexOfSelectedItem)]
        let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = base + "." + language.fileExtension
    }
}

final class LanguageNameField: NSObject {
    let field: NSTextField
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let languages = NewFilePrompt.languages

    init(language: BufferLanguage) {
        field = NSTextField(string: NewFilePrompt.untitledName(for: language))
        super.init()
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        for item in languages {
            popup.addItem(withTitle: item.title ?? item.fileExtension)
        }
        popup.selectItem(at: languages.firstIndex(of: language) ?? 0)
        popup.target = self
        popup.action = #selector(changed)
    }

    var accessory: NSView {
        let label = NSTextField(labelWithString: "Language:")
        let stack = NSStackView(views: [label, popup, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setFrameSize(NSSize(width: 260, height: 78))
        return stack
    }

    @objc private func changed() {
        let language = languages[max(0, popup.indexOfSelectedItem)]
        let base = (field.stringValue as NSString).deletingPathExtension
        if base.isEmpty {
            field.stringValue = NewFilePrompt.untitledName(for: language)
        } else {
            field.stringValue = base + "." + language.fileExtension
        }
    }
}
