import AppKit

final class RenameController {
    static let shared = RenameController()
    weak var state: AppState?
    private var context: Context?
    private let box = RenameInlineBox()

    private struct Context {
        let sessionId: UInt64
        let view: RideTextView
        let caretByte: UInt32
        let name: String
        let range: NSRange
    }

    func begin(state: AppState) {
        guard prepare(state: state), let context else {
            return
        }
        box.onCommit = { [weak self] in self?.commit($0) }
        box.onCancel = { [weak self] in self?.box.hide() }
        let rect = context.view.firstRect(forCharacterRange: context.range, actualRange: nil)
        box.show(over: context.view, screenRect: rect, text: context.name)
    }

    func commit(_ newName: String) {
        box.hide()
        _ = resolve(newName, present: true, localOnly: false)
    }

    @discardableResult
    func applyLocalDirect(_ newName: String) -> Bool {
        resolve(newName, present: false, localOnly: true)
    }

    @discardableResult
    func buildPreview(_ newName: String) -> Bool {
        resolve(newName, present: false, localOnly: false)
    }

    func applyWorkspace() {
        guard let state, let plan = state.renamePlan else {
            return
        }
        let selection = state.renamePreview.selection
        RenameApply.applyWorkspace(
            state: state,
            plan: plan,
            chosenFiles: Set(selection.chosenFilePaths),
            chosenReview: Set(selection.chosenReviewIds)
        )
        state.showRenamePreview = false
        state.renamePlan = nil
    }

    @discardableResult
    func prepare(state: AppState) -> Bool {
        self.state = state
        context = nil
        guard let view = EditorPanes.shared.focusedView,
              let document = state.activeBuffer,
              let id = document.sessionId,
              !document.isReadOnly
        else {
            return false
        }
        let ns = view.string as NSString
        guard let range = IdentifierRange.at(ns, index: view.selectedRange().location) else {
            return false
        }
        let caretByte = UInt32(Utf16.utf8Offset(in: view.string, utf16: range.location))
        context = Context(sessionId: id, view: view, caretByte: caretByte, name: ns.substring(with: range), range: range)
        return true
    }

    private func resolve(_ newName: String, present: Bool, localOnly: Bool) -> Bool {
        guard let context, let engine = RideEngineClient.shared.engine else {
            return false
        }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != context.name else {
            return false
        }
        let local = engine.renameLocal(sessionId: context.sessionId, cursorByte: context.caretByte, newName: trimmed)
        if !local.isEmpty {
            RenameApply.applyLocal(local, to: context.view)
            return true
        }
        if localOnly {
            return false
        }
        let plan = engine.renamePlan(sessionId: context.sessionId, cursorByte: context.caretByte, newName: trimmed)
        return load(plan, present: present)
    }

    private func load(_ plan: RenamePlan, present: Bool) -> Bool {
        guard let state, !(plan.files.isEmpty && plan.review.isEmpty) else {
            return false
        }
        state.renamePlan = plan
        let files = plan.files.map { RenamePreviewFile(path: $0.path, count: $0.edits.count) }
        let reviewFiles = plan.review.map { RenamePreviewFile(path: $0.path, count: $0.edits.count) }
        let review = RenameSelection.reviewRows(from: reviewFiles)
        state.renamePreview.load(name: plan.name, newName: plan.newName, files: files, review: review)
        if present {
            state.showRenamePreview = true
        }
        return true
    }
}
