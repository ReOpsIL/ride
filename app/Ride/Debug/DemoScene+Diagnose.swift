import AppKit

final class DemoStage {
    var typed = false
    var busy = false
    var done = false
    var attempts = 0
}

extension DemoScene {
    static let liveTypo = "factr"

    static func diagnose(_ name: String, state: AppState) -> Bool {
        switch name {
        case "intentions":
            let stage = DemoStage()
            editor(state)
            ready(when: { intentionsStaged(state, stage: stage) }, timeout: 120)
        case "livecheck":
            let stage = DemoStage()
            editor(state, file: "src/shapes.cpp", line: 22)
            ready(when: { liveStaged(state, stage: stage) }, timeout: 180)
        default:
            return false
        }
        return true
    }

    private static func intentionsStaged(_ state: AppState, stage: DemoStage) -> Bool {
        if stage.done {
            return true
        }
        guard let view = EditorPanes.shared.focusedView, state.activeBuffer?.sessionId != nil else {
            return false
        }
        view.window?.makeFirstResponder(view)
        if !stage.typed {
            insertUnused(view)
            stage.typed = true
            return false
        }
        guard !stage.busy, place(on: "unused = 1") else {
            return false
        }
        popIntentions(state, stage: stage)
        return false
    }

    private static func insertUnused(_ view: RideTextView) {
        let starts = view.lineIndex().starts
        guard starts.count >= 9 else {
            return
        }
        let at = starts[8]
        view.setSelectedRange(NSRange(location: at, length: 0))
        view.insertText("    let unused = 1;\n", replacementRange: NSRange(location: at, length: 0))
        guard let binding = view.hooks.binding?() else {
            return
        }
        SessionService.shared.resync(document: binding.document, view: view)
    }

    private static func popIntentions(_ state: AppState, stage: DemoStage) {
        guard let target = EditorCommands.target(), let id = target.document.sessionId else {
            return
        }
        stage.busy = true
        let scheduled = IntentionActions.fetch(
            sessionId: id,
            path: target.document.fileURL?.standardizedFileURL.path,
            text: target.text,
            caret: target.selection.location
        ) { items in
            stage.busy = false
            guard !items.isEmpty else {
                return
            }
            stage.done = true
            let menu = IntentionMenu.menu(items, view: target.view)
            DemoLaunch.after(8.0) { menu.cancelTracking() }
            menu.popUp(positioning: nil, at: IntentionMenu.origin(of: target), in: target.view)
        }
        if !scheduled {
            stage.busy = false
        }
    }

    private static func liveStaged(_ state: AppState, stage: DemoStage) -> Bool {
        guard let view = EditorPanes.shared.focusedView,
              let binding = view.hooks.binding?(),
              binding.document.sessionId != nil
        else {
            return false
        }
        if !stage.typed {
            view.window?.makeFirstResponder(view)
            guard typeTypo(state) else {
                return false
            }
            state.showProblems = true
            stage.typed = true
            state.scheduleLiveCheck(binding.document, view: view)
            return false
        }
        if hasLiveTypo() {
            return true
        }
        stage.attempts += 1
        if stage.attempts % 20 == 0 {
            state.scheduleLiveCheck(binding.document, view: view)
        }
        return false
    }

    private static func typeTypo(_ state: AppState) -> Bool {
        let e = SelfTestEditor(state: state)
        guard e.text.contains("Real Circle::area() const {") else {
            return false
        }
        e.place(on: "Real Circle::area() const {", atEnd: true)
        EditorCommands.newLine(before: false)
        e.type("Real scaled = radius_ * \(liveTypo);")
        return true
    }

    private static func hasLiveTypo() -> Bool {
        CheckService.shared.snapshot.contains { $0.origin == .live && $0.message.contains(liveTypo) }
    }
}
