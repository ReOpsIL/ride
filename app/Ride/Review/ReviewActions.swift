import AppKit
import Foundation

extension ReviewModel {
    func mark(_ row: ReviewRow, root: String?, kind: String, note: String) {
        guard let root, !root.isEmpty else {
            return
        }
        let written = ReviewMark(
            path: row.path,
            item: row.item,
            kind: row.kind,
            mark: kind,
            note: note,
            basis: row.shape
        )
        run(root: root) { engine in
            try engine.reviewMark(root: root, mark: written)
        }
    }

    func drop(_ row: ReviewRow, root: String?) {
        drop(id: row.markId, root: root)
    }

    func drop(id: String, root: String?) {
        guard let root, !root.isEmpty, !id.isEmpty else {
            return
        }
        run(root: root) { engine in
            try engine.reviewDrop(root: root, id: id)
        }
    }

    func copySummary(root: String?) {
        copy(root: root, label: "review summary") { engine, root in
            try engine.reviewSummary(root: root)
        }
    }

    func copyBrief(root: String?) {
        copy(root: root, label: "agent brief") { engine, root in
            try engine.reviewBrief(root: root)
        }
    }

    private func copy(root: String?, label: String, load: @escaping (Engine, String) throws -> String) {
        guard let root, !root.isEmpty else {
            return
        }
        RideEngineClient.shared.withEngine { engine in
            Result { try load(engine, root) }
        } then: { [weak self] result in
            switch result {
            case .success(let text):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self?.notice = "Copied \(label)"
            case .failure(let error):
                self?.error = GitErrorText.message(error)
            }
        }
    }

    private func run(root: String, work: @escaping (Engine) throws -> Void) {
        RideEngineClient.shared.withEngine { engine in
            Result { try work(engine) }
        } then: { [weak self] result in
            switch result {
            case .success:
                self?.reload(root: root)
            case .failure(let error):
                self?.error = GitErrorText.message(error)
            }
        }
    }
}
