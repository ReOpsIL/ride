import AppKit

extension SelfTestSteps {
    static func menusRename(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let rename = RenameController.shared
        let onProbe = { c.resetProbe(); c.caret(on: "let mut probe", offset: 9) }
        let editing = { rename.isEditingName && fieldEditor() != nil }
        let untouched = { e.text == SelfTestMenuContext.probeSource }
        return [
            c.step("menu rename", "Navigate › Rename…", until: editing, timeout: 3, prepare: onProbe) {
                (editing(), "editing \(rename.isEditingName) field \(fieldEditor() != nil)")
            },
            SelfTestStep(name: "menu rename commit", wait: 0.4, run: {
                guard let editor = fieldEditor() else {
                    return
                }
                editor.selectAll(nil)
                editor.insertText("probe2", replacementRange: editor.selectedRange())
                editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
            }, check: {
                let renamed = e.text.components(separatedBy: "probe2").count - 1
                return e.expect(!rename.isEditingName && renamed == 4 && !e.text.contains("probe.bump"), "renamed \(renamed) editing \(rename.isEditingName)")
            }),
            c.step("menu rename again", "Navigate › Rename…", until: editing, timeout: 3, prepare: onProbe) {
                (editing(), "editing \(rename.isEditingName)")
            },
            SelfTestStep(name: "menu rename click away", run: {
                if let view = e.view {
                    view.window?.makeFirstResponder(view)
                }
            }, check: {
                e.expect(!rename.isEditingName && untouched(), "editing \(rename.isEditingName)")
            }),
            c.step("menu rename escape open", "Navigate › Rename…", until: editing, timeout: 3, prepare: onProbe) {
                (editing(), "editing \(rename.isEditingName)")
            },
            SelfTestStep(name: "menu rename escape", run: {
                fieldEditor()?.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
            }, check: {
                e.expect(!rename.isEditingName && untouched() && e.view?.window?.firstResponder === e.view, "editing \(rename.isEditingName)")
            }),
            c.step("menu rename notice", "Navigate › Rename…", prepare: {
                c.resetProbe()
                e.caret(line: c.lineOf("fn menu_probe_unused") - 1)
            }) {
                (!rename.isEditingName && state.notice == RenameController.renameNotice, "notice \(state.notice ?? "nil")")
            },
            c.step("menu safe delete", "Navigate › Safe Delete…", until: { state.showRenamePreview }, timeout: 10, prepare: {
                c.caret(on: "fn menu_probe_unused", offset: 4)
            }) {
                (state.showRenamePreview && state.renamePreview.title.hasPrefix("Safe Delete"), "sheet \(state.showRenamePreview) title \(state.renamePreview.title)")
            },
            SelfTestStep(name: "menu safe delete apply", wait: 0.5, run: { rename.applyWorkspace() }, check: {
                e.expect(!state.showRenamePreview && !e.text.contains("menu_probe_unused"), "sheet \(state.showRenamePreview)")
            }),
        ]
    }

    static func fieldEditor() -> NSTextView? {
        let responder = NSApp.keyWindow?.firstResponder ?? EditorPanes.shared.focusedView?.window?.firstResponder
        guard let editor = responder as? NSTextView, editor.isFieldEditor else {
            return nil
        }
        return editor
    }
}
