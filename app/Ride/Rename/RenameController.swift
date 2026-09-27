import AppKit

final class RenameController {
    static let shared = RenameController()
    weak var state: AppState?
    private var context: Context?
    private let box = RenameInlineBox()
    private var wanted: String?
    private static let safeDeleteNotice = "Place the caret on an item name to delete"
    static let renameNotice = "Place the caret on a name to rename"

    var isEditingName: Bool {
        box.isShown
    }

    private struct Context {
        let document: BufferDocument
        let view: RideTextView
        let caretByte: UInt32
        let name: String
        let range: NSRange
    }

    func begin(state: AppState) {
        guard prepare(state: state), let context else {
            state.showNotice(Self.renameNotice)
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

    func beginSafeDelete(state: AppState) {
        let started = prepare(state: state) && fetchSafeDelete { [weak self] plan in
            guard let plan else {
                state.showNotice(Self.safeDeleteNotice)
                return
            }
            _ = self?.load(
                plan,
                present: true,
                title: "Safe Delete \(plan.name)",
                applyTitle: "Delete",
                reviewTitle: "Usages that would break"
            )
        }
        if !started {
            state.showNotice(Self.safeDeleteNotice)
        }
    }

    @discardableResult
    func applySafeDeleteDirect(state: AppState) -> Bool {
        prepare(state: state) && fetchSafeDelete { [weak self] plan in
            guard let plan, plan.review.isEmpty, let context = self?.context,
                  let edits = plan.files.first?.edits, !edits.isEmpty
            else {
                return
            }
            RenameApply.applyLocal(edits, to: context.view)
        }
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
            chosenReview: Set(selection.chosenReviewIds),
            expected: state.renameExpected
        )
        state.showRenamePreview = false
        state.renamePlan = nil
        state.renameExpected = [:]
        wanted = nil
    }

    @discardableResult
    func prepare(state: AppState) -> Bool {
        self.state = state
        context = nil
        guard let (view, document) = state.focusedEditor,
              document.sessionId != nil,
              !document.isReadOnly
        else {
            return false
        }
        let ns = view.string as NSString
        guard let range = IdentifierRange.at(ns, index: view.selectedRange().location) else {
            return false
        }
        let caretByte = UInt32(Utf16.utf8Offset(in: view.string, utf16: range.location))
        context = Context(document: document, view: view, caretByte: caretByte, name: ns.substring(with: range), range: range)
        return true
    }

    private func resolve(_ newName: String, present: Bool, localOnly: Bool) -> Bool {
        guard let context else {
            return false
        }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != context.name else {
            return false
        }
        let caret = context.caretByte
        let local = SessionService.shared.readNow(context.document) {
            $0.renameLocal(sessionId: $1, cursorByte: caret, newName: trimmed)
        } ?? []
        if !local.isEmpty {
            RenameApply.applyLocal(local, to: context.view)
            return true
        }
        if localOnly {
            return false
        }
        wanted = trimmed
        return SessionService.shared.read(context.document, lane: .workspace, delivery: .currentText, {
            $0.renamePlan(sessionId: $1, cursorByte: caret, newName: trimmed)
        }, then: { [weak self] plan in
            guard let self, self.wanted == plan.newName else {
                return
            }
            _ = self.load(
                plan,
                present: present,
                title: "Rename \(plan.name) to \(plan.newName)",
                applyTitle: "Rename",
                reviewTitle: "Review — could not verify these are the same symbol"
            )
        })
    }

    private func fetchSafeDelete(_ done: @escaping (RenamePlan?) -> Void) -> Bool {
        guard let context else {
            return false
        }
        let caret = context.caretByte
        wanted = ""
        return SessionService.shared.read(context.document, lane: .workspace, delivery: .currentText, {
            $0.safeDeletePlan(sessionId: $1, cursorByte: caret)
        }, then: { [weak self] plan in
            guard self?.wanted == plan.newName else {
                return
            }
            done(plan.files.isEmpty && plan.review.isEmpty ? nil : plan)
        })
    }

    private func load(
        _ plan: RenamePlan,
        present: Bool,
        title: String,
        applyTitle: String,
        reviewTitle: String
    ) -> Bool {
        guard let state, !(plan.files.isEmpty && plan.review.isEmpty) else {
            return false
        }
        state.renamePlan = plan
        state.renameExpected = RenameExpected.capture(plan: plan, state: state)
        let files = plan.files.map { RenamePreviewFile(path: $0.path, count: $0.edits.count) }
        let reviewFiles = plan.review.map { RenamePreviewFile(path: $0.path, count: $0.edits.count) }
        let review = RenameSelection.reviewRows(from: reviewFiles)
        state.renamePreview.load(
            name: plan.name,
            newName: plan.newName,
            files: files,
            review: review,
            title: title,
            applyTitle: applyTitle,
            reviewTitle: reviewTitle
        )
        if present {
            state.showRenamePreview = true
        }
        return true
    }
}
