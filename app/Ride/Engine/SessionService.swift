import AppKit

struct PendingEdit {
    let range: NSRange
    let inserted: String
    let before: String
}

final class SessionService {
    static let shared = SessionService()
    private var queues: [UInt64: DispatchQueue] = [:]
    private let lock = NSLock()

    func queue(_ id: UInt64) -> DispatchQueue {
        lock.lock()
        defer { lock.unlock() }
        if let existing = queues[id] {
            return existing
        }
        let created = DispatchQueue(label: "ride.session.\(id)")
        queues[id] = created
        return created
    }

    func attach(document: BufferDocument, view: RideTextView) {
        guard document.hasSession else {
            return
        }
        if document.sessionId == nil {
            if !document.sessionOpening {
                open(document: document, view: view)
            }
        } else {
            HighlightApply.restyle(spans: document.highlights, text: view.string, view: view)
            resync(document: document, view: view)
            FoldController.shared.restore(document: document, view: view)
        }
    }

    func close(_ document: BufferDocument) {
        document.sessionGeneration += 1
        document.sessionOpening = false
        guard let id = document.sessionId else {
            return
        }
        document.sessionId = nil
        RideEngineClient.shared.engine?.closeSession(sessionId: id)
        lock.lock()
        queues.removeValue(forKey: id)
        lock.unlock()
    }

    func applyEdit(document: BufferDocument, view: RideTextView, edit: InputEditFfi, inserted: String) {
        guard let id = document.sessionId else {
            attach(document: document, view: view)
            return
        }
        document.editCount += 1
        if document.editCount % 200 == 0 {
            resync(document: document, view: view)
            return
        }
        let vis = visible(view)
        let mark = document.textGeneration
        queue(id).async {
            let update = try? RideEngineClient.shared.engine?.applyEdit(
                sessionId: id,
                edit: edit,
                insertedText: inserted,
                visible: vis
            )
            self.deliver(update, document: document, session: id, mark: mark)
        }
    }

    func setVisible(document: BufferDocument, view: RideTextView) {
        guard let id = document.sessionId, let vis = visible(view) else {
            return
        }
        document.visibleWork?.cancel()
        let work = DispatchWorkItem {
            let mark = document.textGeneration
            self.queue(id).async {
                let update = try? RideEngineClient.shared.engine?.setVisibleRange(sessionId: id, visible: vis)
                self.deliver(update, document: document, session: id, mark: mark)
            }
        }
        document.visibleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    func resync(document: BufferDocument, view: RideTextView) {
        guard document.hasSession else {
            return
        }
        guard let id = document.sessionId else {
            if !document.sessionOpening {
                open(document: document, view: view)
            }
            return
        }
        let text = view.string
        let vis = visible(view)
        let mark = document.textGeneration
        queue(id).async {
            let update = try? RideEngineClient.shared.engine?.setText(sessionId: id, text: text, visible: vis)
            self.deliver(update, document: document, session: id, mark: mark)
        }
    }

    private func deliver(_ update: SessionUpdate?, document: BufferDocument, session id: UInt64, mark: Int) {
        DispatchQueue.main.async {
            guard let update, document.sessionId == id, let edits = document.journal.edits(since: mark),
                  let view = EditorPanes.shared.host(bound: document)?.textView
            else {
                return
            }
            self.paint(update.rebased(through: edits), document: document, view: view)
        }
    }

    private func open(document: BufferDocument, view: RideTextView) {
        let text = view.string
        let vis = visible(view)
        let bufferId = document.id.uuidString
        let path = document.fileURL?.path
        let generation = document.sessionGeneration
        let mark = document.textGeneration
        document.sessionOpening = true
        DispatchQueue.global(qos: .userInitiated).async {
            let opened = try? RideEngineClient.shared.engine?.openSession(
                bufferId: bufferId,
                path: path,
                text: text,
                visible: vis
            )
            DispatchQueue.main.async {
                self.opened(opened, document: document, generation: generation, mark: mark)
            }
        }
    }

    private func opened(_ opened: SessionOpen?, document: BufferDocument, generation: Int, mark: Int) {
        guard document.sessionGeneration == generation else {
            if let id = opened?.sessionId {
                RideEngineClient.shared.engine?.closeSession(sessionId: id)
            }
            return
        }
        document.sessionOpening = false
        document.sessionId = opened?.sessionId
        guard let view = EditorPanes.shared.host(bound: document)?.textView else {
            return
        }
        if let lang = opened?.lang {
            document.detectedLanguage = BufferLanguage(lang)
            document.updateLabel(view)
        }
        guard document.textGeneration == mark else {
            resync(document: document, view: view)
            return
        }
        if let update = opened?.update {
            paint(update, document: document, view: view)
        }
        FoldController.shared.restore(document: document, view: view)
        UsageIndexer.index([document])
    }

    private func visible(_ view: RideTextView) -> ByteRange? {
        guard let length = view.textStorage?.length, length >= 1_048_576 else {
            return nil
        }
        return view.visibleBytes()
    }

    static func row(_ item: OutlineItem) -> OutlineRow {
        OutlineRow(
            name: item.name,
            kindLabel: kindLabel(item.kind),
            startByte: item.startByte,
            endByte: item.endByte,
            nameStartByte: item.nameStartByte,
            scope: item.scope.map { OutlineRow.Scope(label: $0.label, startByte: $0.startByte, endByte: $0.endByte) }
        )
    }
}
