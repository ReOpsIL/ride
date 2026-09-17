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
            livePanelSeam(state: state, e: e),
            liveDropCancels(state: state, e: e),
            liveStaleGuarded(state: state, e: e),
        ]
    }

    private static func shapesURL(_ state: AppState) -> URL? {
        state.workspaceRoot?.appendingPathComponent("src/shapes.cpp")
    }

    private static func hasLive(_ state: AppState, marker: String) -> Bool {
        CheckService.shared.snapshot.contains { $0.origin == .live && $0.message.contains(marker) }
    }

    private static func errItem(_ path: String, _ marker: String) -> StoredDiagnostic {
        StoredDiagnostic(
            path: path, byteStart: 1, byteEnd: 2, line: 1, column: 1,
            level: .error, message: marker, code: nil
        )
    }

    private static func livePanelSeam(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "live diagnostic keeps panel", wait: 0.3, run: {
            guard let path = shapesURL(state)?.path else { return }
            state.showProblems = false
            let gen = CheckService.shared.bump(CheckService.livePrefix + path)
            CheckService.shared.setLive(path: path, diagnostics: [errItem(path, "ride_seam_live")], generation: gen)
        }, check: {
            guard let path = shapesURL(state)?.path else { return "no shapes path" }
            let liveOpened = state.showProblems
            state.showProblems = false
            state.checkFinished([CheckConvert.ffi(errItem(path, "ride_seam_save"))])
            let saveOpened = state.showProblems
            state.showProblems = false
            CheckService.shared.dropClang(path: path)
            return e.expect(!liveOpened && saveOpened, "liveOpened \(liveOpened) saveOpened \(saveOpened)")
        })
    }

    private static func liveDropCancels(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "live drop cancels", wait: 0.3, run: {
            guard let path = shapesURL(state)?.path else { return }
            let armed = CheckService.shared.bump(CheckService.livePrefix + path)
            CheckService.shared.dropClang(path: path)
            CheckService.shared.setLive(path: path, diagnostics: [errItem(path, "ride_drop_live")], generation: armed)
        }, check: {
            e.expect(!hasLive(state, marker: "ride_drop_live"), "dropped path resurrected")
        })
    }

    private static func liveStaleGuarded(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "live stale guarded", wait: 0.3, run: {
            guard let path = shapesURL(state)?.path else { return }
            let stale = CheckService.shared.bump(CheckService.livePrefix + path)
            let fresh = CheckService.shared.bump(CheckService.livePrefix + path)
            CheckService.shared.setLive(path: path, diagnostics: [errItem(path, "ride_stale_live")], generation: stale)
            CheckService.shared.setLive(path: path, diagnostics: [errItem(path, "ride_fresh_live")], generation: fresh)
        }, check: {
            guard let path = shapesURL(state)?.path else { return "no shapes path" }
            let staleDropped = !hasLive(state, marker: "ride_stale_live")
            let freshApplied = hasLive(state, marker: "ride_fresh_live")
            CheckService.shared.dropClang(path: path)
            return e.expect(staleDropped && freshApplied, "staleDropped \(staleDropped) freshApplied \(freshApplied)")
        })
    }

    private static func liveDiagnosticPrep(state: AppState, e: SelfTestEditor, scratch: LiveScratch) -> SelfTestStep {
        SelfTestStep(name: "live diagnostic prep", wait: 1.2, run: {
            if let url = shapesURL(state) {
                state.openFile(url)
            }
            scratch.wasAutoSave = state.prefs.autoSave
            state.updatePrefs { $0.autoSave = false }
            state.buffers.forEach { $0.autoSaveWork?.cancel() }
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
