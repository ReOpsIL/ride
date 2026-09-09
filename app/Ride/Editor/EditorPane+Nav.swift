import AppKit

extension EditorPane.Coordinator {
    func installHooks(_ view: RideTextView) {
        view.hooks.goToDefinition = { [weak self] utf16 in
            guard let self else {
                return
            }
            self.state.goToDefinition(document: self.document, view: view, utf16: utf16)
        }
        view.hooks.definitions = { [weak self] utf16, done in
            guard let self else {
                return
            }
            Definitions.lookup(document: self.document, view: view, utf16: utf16, done: done)
        }
    }
}
