import AppKit

extension SelfTestSteps {
    static func renameSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [focusMain(state: state, e: e), renameLocal(state: state, e: e), renameWorkspacePreview(state: state, e: e)]
    }

    private static func focusMain(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "rename focus main", wait: 0.4, until: {
            if state.activeBuffer?.fileURL?.lastPathComponent == "main.rs" {
                return true
            }
            guard let root = state.workspaceRoot else {
                return true
            }
            state.openFile(root.appendingPathComponent("src/main.rs"))
            return false
        }, timeout: 20, run: {}, check: {
            e.focus()
            return e.expect(
                state.activeBuffer?.fileURL?.lastPathComponent == "main.rs" && e.text.contains("fn main"),
                "active \(state.activeBuffer?.fileURL?.lastPathComponent ?? "nil")"
            )
        })
    }

    private static func renameLocal(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "rename local", wait: 0.4, run: {
            e.focus()
            e.place(on: "counter")
            RenameController.shared.prepare(state: state)
            RenameController.shared.applyLocalDirect("tally")
        }, check: {
            let tally = e.text.components(separatedBy: "tally").count - 1
            return e.expect(
                tally == 6 && !e.text.contains("counter") && e.text.contains("Counter::new"),
                "tally \(tally) line9 '\(e.line(9))'"
            )
        })
    }

    private static func renameWorkspacePreview(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "rename workspace preview", wait: 0.4, until: {
            if renameHasBothFiles(state) {
                return true
            }
            state.indexOpenBuffers()
            e.focus()
            e.place(on: "record")
            RenameController.shared.prepare(state: state)
            RenameController.shared.buildPreview("logged")
            return false
        }, timeout: 30, run: {}, check: {
            e.expect(
                renameHasBothFiles(state),
                "paths \(renamePaths(state))"
            )
        })
    }

    private static func renamePaths(_ state: AppState) -> [String] {
        let selection = state.renamePreview.selection
        return selection.files.map(\.path) + selection.review.map(\.path)
    }

    private static func renameHasBothFiles(_ state: AppState) -> Bool {
        let paths = renamePaths(state)
        return paths.contains { $0.hasSuffix("main.rs") } && paths.contains { $0.hasSuffix("util.rs") }
    }
}
