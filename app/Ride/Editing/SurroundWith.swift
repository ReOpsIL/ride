import AppKit

struct SurroundTemplate {
    let title: String
    let open: String
    let close: String
}

enum SurroundWith {
    static func templates(for language: BufferLanguage, tokens: CommentTokens) -> [SurroundTemplate] {
        var out = [
            SurroundTemplate(title: "{ … }", open: "{", close: "}"),
            SurroundTemplate(title: "( … )", open: "(", close: ")"),
            SurroundTemplate(title: "[ … ]", open: "[", close: "]"),
            SurroundTemplate(title: "\" … \"", open: "\"", close: "\""),
        ]
        switch language {
        case .rust:
            out += [
                SurroundTemplate(title: "if", open: "if condition {\n", close: "\n}"),
                SurroundTemplate(title: "loop", open: "loop {\n", close: "\n}"),
                SurroundTemplate(title: "unsafe", open: "unsafe {\n", close: "\n}"),
                SurroundTemplate(title: "match", open: "match value {\n", close: "\n}"),
                SurroundTemplate(title: "Some( … )", open: "Some(", close: ")"),
                SurroundTemplate(title: "Ok( … )", open: "Ok(", close: ")"),
            ]
        case .c, .cpp:
            out += [
                SurroundTemplate(title: "if", open: "if (condition) {\n", close: "\n}"),
                SurroundTemplate(title: "while", open: "while (condition) {\n", close: "\n}"),
                SurroundTemplate(title: "#if 0 … #endif", open: "#if 0\n", close: "\n#endif"),
            ]
        default:
            break
        }
        if let open = tokens.blockOpen, let close = tokens.blockClose {
            out.append(SurroundTemplate(title: "\(open) … \(close)", open: open + " ", close: " " + close))
        }
        return out
    }

    static func apply(_ template: SurroundTemplate, to target: EditorTarget) -> EditResult {
        let selected = (target.text as NSString).substring(with: target.selection)
        let text = template.open + selected + template.close
        let inner = NSRange(location: target.selection.location + (template.open as NSString).length, length: (selected as NSString).length)
        return EditResult(changes: [TextChange(range: target.selection, text: text)], selection: inner)
    }
}

extension EditorCommands {
    static func surroundWith() {
        guard let target = target() else {
            return
        }
        let menu = NSMenu()
        for template in SurroundWith.templates(for: target.document.language, tokens: target.tokens) {
            let item = NSMenuItem(title: template.title, action: #selector(SurroundMenuTarget.pick(_:)), keyEquivalent: "")
            item.representedObject = SurroundBox(template: template, target: target)
            item.target = SurroundMenuTarget.shared
            menu.addItem(item)
        }
        var actual = NSRange()
        let rect = target.view.firstRect(forCharacterRange: target.selection, actualRange: &actual)
        let origin = target.view.window.map { target.view.convert($0.convertFromScreen(rect).origin, from: nil) } ?? .zero
        menu.popUp(positioning: nil, at: NSPoint(x: origin.x, y: origin.y), in: target.view)
    }
}

final class SurroundBox: NSObject {
    let template: SurroundTemplate
    let target: EditorTarget

    init(template: SurroundTemplate, target: EditorTarget) {
        self.template = template
        self.target = target
    }
}

final class SurroundMenuTarget: NSObject {
    static let shared = SurroundMenuTarget()

    @objc func pick(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? SurroundBox else {
            return
        }
        EditorCommand.apply(SurroundWith.apply(box.template, to: box.target), to: box.target.view)
    }
}
