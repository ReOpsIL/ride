import AppKit

enum Definitions {
    static func lookup(
        document: BufferDocument,
        view: RideTextView,
        utf16: Int,
        done: @escaping (DefinitionResponse) -> Void
    ) {
        guard let engine = RideEngineClient.shared.engine, let id = document.sessionId else {
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: utf16))
        DispatchQueue.global(qos: .userInitiated).async {
            let resp = engine.findDefinitions(sessionId: id, cursorByte: byte)
            DispatchQueue.main.async {
                done(resp)
            }
        }
    }
}

extension AppState {
    func goToDefinition() {
        guard let view = EditorJump.shared.view, let document = activeBuffer else {
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
