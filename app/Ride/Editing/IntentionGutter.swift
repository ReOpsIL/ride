import AppKit

final class IntentionGutter {
    static let shared = IntentionGutter()
    static let delay: TimeInterval = 0.15
    private var generation = 0
    private var pending: DispatchWorkItem?

    func stop() {
        generation += 1
        pending?.cancel()
        pending = nil
    }

    func caretMoved(document: BufferDocument, view: RideTextView) {
        stop()
        let generation = generation
        let work = DispatchWorkItem { [weak self, weak view] in
            guard let self, let view else {
                return
            }
            refresh(document: document, view: view, generation: generation)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    private func refresh(document: BufferDocument, view: RideTextView, generation: Int) {
        guard generation == self.generation, let id = document.sessionId else {
            return
        }
        let caret = view.selectedRange().location
        let line = view.lineIndex().line(at: caret)
        IntentionActions.fetch(
            sessionId: id,
            path: document.fileURL?.standardizedFileURL.path,
            text: view.string,
            caret: caret,
            qos: .utility
        ) { [weak self, weak view] items in
            guard let self, generation == self.generation, let view else {
                return
            }
            EditorPanes.shared.host(for: view)?.gutter.intentionLines = items.isEmpty ? [] : [line]
        }
    }
}
