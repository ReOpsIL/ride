import AppKit

struct OutlineRow: Identifiable, Equatable {
    let name: String
    let kindLabel: String
    let startByte: UInt32
    let endByte: UInt32
    var id: UInt32 { startByte }
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

    private func queue(_ id: UInt64) -> DispatchQueue {
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
            open(document: document, view: view)
        } else {
            HighlightApply.restyle(
                spans: document.highlights,
                text: view.string,
                view: view,
                visible: nil
            )
            resync(document: document, view: view)
        }
    }

    func close(_ document: BufferDocument) {
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
            open(document: document, view: view)
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
        DispatchQueue.global(qos: .userInitiated).async {
            let opened = try? RideEngineClient.shared.engine?.openSession(
                bufferId: bufferId,
                path: path,
                text: text,
                visible: vis
            )
            DispatchQueue.main.async {
                document.sessionId = opened?.sessionId
                self.paint(opened?.update, document: document, view: view, text: view.string)
            }
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

    static func kindLabel(_ kind: ItemKind) -> String {
        switch kind {
        case .keyword: return "kw"
        case .local: return "local"
        case .crate: return "crate"
        case .mod: return "mod"
        case .`struct`: return "struct"
        case .`enum`: return "enum"
        case .union: return "union"
        case .trait: return "trait"
        case .fn: return "fn"
        case .method: return "method"
        case .macro: return "macro"
        case .const: return "const"
        case .type: return "type"
        case .`static`: return "static"
        case .heading: return "heading"
        }
    }
}
