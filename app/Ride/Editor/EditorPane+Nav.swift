import AppKit

extension EditorPane.Coordinator {
    func installHooks(_ view: RideTextView) {
        view.hooks.goToDefinition = { [weak self, weak view] utf16 in
            guard let self, let view else {
                return
            }
            self.state.goToDefinition(document: self.document, view: view, utf16: utf16)
        }
        view.hooks.definitions = { [weak self, weak view] utf16, done in
            guard let self, let view else {
                return
            }
            Definitions.lookup(document: self.document, view: view, utf16: utf16, done: done)
        }
        view.hooks.binding = { [weak self] in
            self.map { EditorBinding(document: $0.document, state: $0.state) }
        }
    }
}
