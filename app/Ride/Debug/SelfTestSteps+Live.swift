import AppKit

final class LiveScratch {
    var line = 0
    var disk = ""
    var wasAutoSave = true
    let marker = "ride_live_undeclared_zz"
}

extension SelfTestSteps {
    static func liveSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let scratch = LiveScratch()
        return [
            liveDiagnosticPrep(state: state, e: e, scratch: scratch),
            liveDiagnosticAppears(state: state, e: e, scratch: scratch),
            liveDiagnosticClears(state: state, e: e, scratch: scratch),
        ]
    }

    private static func shapesURL(_ state: AppState) -> URL? {
        state.workspaceRoot?.appendingPathComponent("src/shapes.cpp")
    }

    private static func hasLive(_ state: AppState, marker: String) -> Bool {
        CheckService.shared.snapshot.contains { $0.origin == .live && $0.message.contains(marker) }
    }

    private static func liveDiagnosticPrep(state: AppState, e: SelfTestEditor, scratch: LiveScratch) -> SelfTestStep {
        SelfTestStep(name: "live diagnostic prep", wait: 1.2, run: {
            if let url = shapesURL(state) {
                state.openFile(url)
            }
            scratch.wasAutoSave = state.prefs.autoSave
            state.updatePrefs { $0.autoSave = false }
            state.autoSaveWork?.cancel()
            scratch.disk = shapesURL(state).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            e.focus()
        }, check: {
            e.expect(!scratch.disk.isEmpty && e.text.contains("Circle::area"), "no shapes buffer")
        })
    }

    private static func liveDiagnosticAppears(state: AppState, e: SelfTestEditor, scratch: LiveScratch) -> SelfTestStep {
        SelfTestStep(name: "live diagnostic appears", wait: 0.3, until: { hasLive(state, marker: scratch.marker) }, timeout: 90, run: {
            e.activate()
            e.place(on: "std::ostringstream out;", atEnd: true)
            EditorCommands.newLine(before: false)
            e.type("\(scratch.marker);")
            scratch.line = e.caretLine
            if let view = e.view, let binding = view.hooks.binding?() {
                state.scheduleLiveCheck(binding.document, view: view)
            }
        }, check: {
            let onLine = CheckService.shared.snapshot.contains {
                $0.origin == .live && $0.message.contains(scratch.marker) && Int($0.line) == scratch.line
            }
            let disk = shapesURL(state).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            return e.expect(onLine && disk == scratch.disk && !disk.contains(scratch.marker), "line \(scratch.line) wrote \(disk != scratch.disk)")
        })
    }

    private static func liveDiagnosticClears(state: AppState, e: SelfTestEditor, scratch: LiveScratch) -> SelfTestStep {
        SelfTestStep(name: "live diagnostic clears", wait: 0.3, until: { !hasLive(state, marker: scratch.marker) }, timeout: 90, run: {
            e.activate()
            e.place(on: "\(scratch.marker);")
            EditorCommands.deleteLines()
            if let view = e.view, let binding = view.hooks.binding?() {
                state.scheduleLiveCheck(binding.document, view: view)
            }
        }, check: {
            let disk = shapesURL(state).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            let cleared = !hasLive(state, marker: scratch.marker) && !e.text.contains(scratch.marker)
            state.updatePrefs { $0.autoSave = scratch.wasAutoSave }
            return e.expect(cleared && disk == scratch.disk, "cleared \(cleared) wrote \(disk != scratch.disk)")
        })
    }
}
