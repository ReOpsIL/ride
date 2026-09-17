import AppKit

struct OutlineRow: Identifiable, Equatable {
    let name: String
    let kindLabel: String
    let startByte: UInt32
    let endByte: UInt32
    var id: String { "\(startByte):\(name)" }
}

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
            HighlightApply.restyle(
                spans: document.highlights,
                text: view.string,
                view: view,
                visible: nil
            )
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
        let text = view.string
        let vis = visible(view: view, text: text)
        queue(id).async {
            let update = try? RideEngineClient.shared.engine?.applyEdit(
                sessionId: id,
                edit: edit,
                insertedText: inserted,
                visible: vis
            )
            DispatchQueue.main.async {
                self.paint(update, document: document, view: view, text: view.string)
            }
        }
    }

    func setVisible(document: BufferDocument, view: RideTextView) {
        guard let id = document.sessionId, let vis = view.visibleBytes() else {
            return
        }
        if view.textStorage.map({ $0.length }) ?? 0 < 1_048_576 {
            return
        }
        document.visibleWork?.cancel()
        let work = DispatchWorkItem {
            self.queue(id).async {
                let update = try? RideEngineClient.shared.engine?.setVisibleRange(sessionId: id, visible: vis)
                DispatchQueue.main.async {
                    self.paint(update, document: document, view: view, text: view.string)
                }
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
        let vis = visible(view: view, text: text)
        queue(id).async {
            let update = try? RideEngineClient.shared.engine?.setText(sessionId: id, text: text, visible: vis)
            DispatchQueue.main.async {
                self.paint(update, document: document, view: view, text: text)
            }
        }
    }

    private func open(document: BufferDocument, view: RideTextView) {
        let text = view.string
        let vis = visible(view: view, text: text)
        let bufferId = document.id.uuidString
        let path = document.fileURL?.path
        let generation = document.sessionGeneration
        document.sessionOpening = true
        DispatchQueue.global(qos: .userInitiated).async {
            let opened = try? RideEngineClient.shared.engine?.openSession(
                bufferId: bufferId,
                path: path,
                text: text,
                visible: vis
            )
            DispatchQueue.main.async {
                self.opened(opened, document: document, generation: generation, sent: text)
            }
        }
    }

    private func opened(_ opened: SessionOpen?, document: BufferDocument, generation: Int, sent: String) {
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
        if view.string != sent {
            resync(document: document, view: view)
            return
        }
        paint(opened?.update, document: document, view: view, text: view.string)
        FoldController.shared.restore(document: document, view: view)
        if let id = opened?.sessionId {
            UsageIndexer.index(sessionId: id)
        }
    }

    private func visible(view: RideTextView, text: String) -> ByteRange? {
        if text.utf8.count < 1_048_576 {
            return nil
        }
        return view.visibleBytes()
    }

    static func row(_ item: OutlineItem) -> OutlineRow {
        OutlineRow(
            name: item.name,
            kindLabel: kindLabel(item.kind),
            startByte: item.startByte,
            endByte: item.endByte
        )
    }
}
