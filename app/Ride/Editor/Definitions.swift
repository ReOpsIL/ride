import AppKit

enum Definitions {
    static func lookup(
        document: BufferDocument,
        view: RideTextView,
        utf16: Int,
        done: @escaping (DefinitionResponse) -> Void
    ) {
        guard let id = document.sessionId else {
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: utf16))
        RideEngineClient.shared.withEngine { engine in
            engine.findDefinitions(sessionId: id, cursorByte: byte)
        } then: { resp in
            done(resp)
        }
    }
}

extension AppState {
    func goToDefinition() {
        if EditorPanes.shared.focused?.peek.openIfVisible() == true {
            return
        }
        guard let (view, document) = focusedEditor else {
            return
        }
        goToDefinition(document: document, view: view, utf16: view.selectedRange().location)
    }

    func goToDefinition(document: BufferDocument, view: RideTextView, utf16: Int) {
        HoverController.shared.hide()
        Definitions.lookup(document: document, view: view, utf16: utf16) { [weak self] resp in
            guard let self, let hit = resp.hits.first else {
                return
            }
            HitNavigation.open(hit, state: self)
        }
    }
}
