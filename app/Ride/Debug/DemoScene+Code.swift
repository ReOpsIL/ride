import AppKit

extension DemoScene {
    static let recordDefinition = "record(&mut self, name: &str);"
    static let recordCall = ".record("

    static func code(_ name: String, state: AppState) -> Bool {
        switch name {
        case "usages":
            editor(state)
            DemoLaunch.after(1.2) { _ = open(state, file: "src/util.rs") }
            ready(when: { usagesStaged(state) })
        case "hierarchy":
            state.prefs.outlinePanel = false
            state.prefs.hierarchyWidth = 360
            editor(state)
            ready(when: { hierarchyStaged(state) })
        case "codevision":
            state.prefs.codeVision = true
            state.prefs.outlinePanel = false
            editor(state)
            DemoLaunch.after(1.2) { _ = open(state, file: "src/util.rs") }
            ready(when: { visionStaged(state) })
        case "rename":
            editor(state)
            DemoLaunch.after(1.2) { _ = open(state, file: "src/util.rs") }
            ready(when: { renameStaged(state) })
        default:
            return false
        }
        return true
    }

    static func place(on needle: String, offset: Int = 0) -> Bool {
        guard let view = EditorPanes.shared.focusedView else {
            return false
        }
        view.window?.makeFirstResponder(view)
        let found = (view.string as NSString).range(of: needle)
        guard found.location != NSNotFound else {
            return false
        }
        view.setSelectedRange(NSRange(location: found.location + offset, length: 0))
        return true
    }

    private static func usagesStaged(_ state: AppState) -> Bool {
        if state.usages.running {
            return false
        }
        if state.showUsages, state.usages.finished, state.usages.name == "record", state.usages.total >= 3 {
            return true
        }
        guard state.activeBuffer?.fileURL?.lastPathComponent == "util.rs",
              place(on: recordDefinition)
        else {
            return false
        }
        state.indexOpenBuffers()
        state.findUsages()
        return false
    }

    private static func hierarchyStaged(_ state: AppState) -> Bool {
        if state.hierarchy.running {
            return false
        }
        if state.showHierarchy, state.hierarchy.rootName == "record", state.hierarchy.childCount >= 2 {
            return true
        }
        guard place(on: recordCall, offset: 1) else {
            return false
        }
        state.indexOpenBuffers()
        state.showCallHierarchy()
        return false
    }

    private static func visionStaged(_ state: AppState) -> Bool {
        guard let document = state.activeBuffer,
              document.fileURL?.lastPathComponent == "util.rs",
              document.outline.contains(where: { $0.name == "record" })
        else {
            return false
        }
        let view = EditorPanes.shared.focusedView
        if (document.visionCounts["record"] ?? 0) > 0, view?.visionLabel(forLine: 10) != nil {
            return true
        }
        state.indexOpenBuffers()
        view?.refreshVision(from: [])
        return false
    }

    private static func renameStaged(_ state: AppState) -> Bool {
        if state.showRenamePreview, renameHasBothFiles(state) {
            return true
        }
        guard state.activeBuffer?.fileURL?.lastPathComponent == "util.rs",
              place(on: recordDefinition)
        else {
            return false
        }
        state.indexOpenBuffers()
        guard RenameController.shared.prepare(state: state) else {
            return false
        }
        RenameController.shared.commit("logged")
        return false
    }

    private static func renameHasBothFiles(_ state: AppState) -> Bool {
        let selection = state.renamePreview.selection
        return selection.files.contains { $0.path.hasSuffix("util.rs") }
            && selection.review.contains { $0.path.hasSuffix("main.rs") }
    }
}
