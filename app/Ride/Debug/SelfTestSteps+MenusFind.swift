import AppKit

extension SelfTestSteps {
    static func menusFind(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        return [
            c.step("menu find", "Edit › Find…", prepare: { state.closeOverlays() }) {
                (state.showFind && !state.showReplaceField, "find \(state.showFind) replace \(state.showReplaceField)")
            },
            c.step("menu find close", "Edit › Find…") {
                (!state.showFind, "find \(state.showFind)")
            },
            c.step("menu find and replace", "Edit › Find and Replace…") {
                (state.showFind && state.showReplaceField, "find \(state.showFind) replace \(state.showReplaceField)")
            },
            c.step("menu find and replace close", "Edit › Find and Replace…") {
                (!state.showFind, "find \(state.showFind)")
            },
            c.step("menu use selection for find", "Edit › Use Selection for Find", prepare: {
                state.findOptions = .defaults
                c.select("probe.bump")
                if let view = e.view {
                    view.setSelectedRange(NSRange(location: view.selectedRange().location, length: 5))
                    c.location = view.selectedRange().location
                }
            }) {
                (state.findQuery == "probe" && !state.showFind, "query '\(state.findQuery)' bar \(state.showFind)")
            },
            c.step("menu find next", "Edit › Find Next") {
                let range = e.view?.selectedRange() ?? NSRange()
                return (e.selectedText.lowercased() == "probe" && range.location > c.location, "selected '\(e.selectedText)' at \(range.location) after \(c.location)")
            },
            c.step("menu find previous", "Edit › Find Previous") {
                let range = e.view?.selectedRange() ?? NSRange()
                return (e.selectedText.lowercased() == "probe" && range.location == c.location, "selected '\(e.selectedText)' at \(range.location) want \(c.location)")
            },
            c.step("menu find in project", "Edit › Find in Project…") {
                (state.showProjectFind && state.projectFind.field == .query, "shown \(state.showProjectFind) field \(state.projectFind.field)")
            },
            c.step("menu replace in project", "Edit › Replace in Project…", wait: 0.6, activating: false) {
                let placeholder = focusedFieldPlaceholder()
                return (
                    state.showProjectFind && state.projectFind.field == .replace && placeholder == "Replace",
                    "shown \(state.showProjectFind) field \(state.projectFind.field) focus '\(placeholder)'"
                )
            },
            c.step("menu find in project refocus", "Edit › Find in Project…", wait: 0.6, activating: false) {
                (state.showProjectFind && state.projectFind.field == .query, "shown \(state.showProjectFind) field \(state.projectFind.field)")
            },
            c.step("menu find in project close", "Edit › Find in Project…", activating: false) {
                (!state.showProjectFind && state.overlay == nil, "overlay \(String(describing: state.overlay))")
            },
        ]
    }

    static func focusedFieldPlaceholder() -> String {
        let editor = (NSApp.keyWindow ?? MainWindow.window)?.firstResponder as? NSTextView
        let field = editor?.delegate as? NSTextField
        return field?.placeholderString ?? field?.placeholderAttributedString?.string ?? "none"
    }
}
