import AppKit

final class DebugLabScratch {
    var path = ""
    var line: UInt32 = 0
    var sequence = 0
    var pressed = false
    var seen = false
    var count = 0
    var filter: Bool?
}

extension SelfTestSteps {
    static func debugLabSteps(state: AppState, e: SelfTestEditor, lab: DebugLab) -> [SelfTestStep] {
        guard DeveloperMode.isEnabled else {
            return [SelfTestStep(name: "debug lab (skipped: developer mode disabled)", wait: 0.1, run: {}, check: { nil })]
        }
        let scratch = DebugLabScratch()
        let throwing = lab.language == .cpp ? labThrowSteps(state: state, e: e, scratch: scratch) : []
        return [labSetup(state: state, e: e)]
            + labSteppingSteps(state: state, e: e, lab: lab, scratch: scratch)
            + labStackSteps(state: state, e: e, lab: lab, scratch: scratch)
            + labRecursionSteps(state: state, e: e, lab: lab, scratch: scratch)
            + labLoopSteps(state: state, e: e, lab: lab, scratch: scratch)
            + labThreadSteps(state: state, e: e, lab: lab, scratch: scratch)
            + labHeartbeatSteps(state: state, e: e, lab: lab, scratch: scratch)
            + throwing
    }

    private static func labSetup(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: SelfTestSelection.setupName, wait: 0.5, until: {
            if state.runTarget?.name != DebugLab.target, let row = state.projectModel.rows.first(where: { $0.kind == .bin && $0.name == DebugLab.target }) {
                state.selectTarget(row)
            }
            return state.runTarget?.name == DebugLab.target && !DebugFilters.shared.toggles.isEmpty
        }, timeout: 120, run: {
            DebugFilters.shared.load()
            state.debugPanel.visible = true
        }, check: {
            e.expect(
                state.runTarget?.name == DebugLab.target && !DebugFilters.shared.toggles.isEmpty,
                "target \(state.runTarget?.name ?? "nil") filters \(DebugFilters.shared.toggles.map(\.id))"
            )
        })
    }

    static func labBreakpoint(_ name: String, state: AppState, e: SelfTestEditor, file: String, anchor: String, scratch: DebugLabScratch) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.6, until: {
            guard e.text.contains(anchor) else {
                return false
            }
            if scratch.line == 0 {
                e.focus()
                e.place(on: anchor)
                scratch.line = UInt32(e.caretLine)
                scratch.path = debugPath(state) ?? ""
            }
            return !marks(state).isEmpty || SelfTestGutter.click(e, line: Int(scratch.line)) && !marks(state).isEmpty
        }, timeout: 15, run: {
            scratch.line = 0
            openRelative(state, file)
        }, check: {
            e.expect(
                scratch.path.hasSuffix(file) && marks(state) == [scratch.line],
                "\(scratch.path):\(scratch.line) marks \(marks(state))"
            )
        })
    }

    static func labBreakpointDialog(_ name: String, state: AppState, e: SelfTestEditor, condition: String, hits: String, scratch: DebugLabScratch) -> SelfTestStep {
        let edited = { state.debug.breakpoints.mark(path: scratch.path, line: scratch.line) }
        let window = { SelfTestGutter.host(e)?.window }
        return SelfTestStep(name: name, wait: 0.5, until: {
            if !scratch.pressed, window()?.attachedSheet != nil {
                scratch.pressed = SelfTestSheet.answer(window(), values: [condition, hits], button: "Save")
            }
            return scratch.pressed && window()?.attachedSheet == nil
        }, timeout: 15, run: {
            scratch.pressed = false
            _ = SelfTestGutter.click(e, line: Int(scratch.line), right: true)
        }, check: {
            let mark = edited()
            return e.expect(
                scratch.pressed && mark?.condition == condition.nilIfEmpty && mark?.hitCondition == hits.nilIfEmpty,
                "saved \(scratch.pressed) condition \(mark?.condition ?? "nil") hits \(mark?.hitCondition ?? "nil")"
            )
        })
    }

    static func labDebug(_ name: String, state: AppState, scenario: String, prepare: @escaping () -> Void = {}, ready: @escaping () -> Bool, check: @escaping () -> String?) -> SelfTestStep {
        let started = DebugLabScratch()
        return SelfTestStep(name: name, wait: 0.5, until: {
            guard started.pressed else {
                started.pressed = SelfTestShortcut.press("Debug › Debug", in: SelfTestKeys.mainWindow)
                return false
            }
            started.seen = started.seen || state.runOutput.isRunning || state.debug.isActive
            return ready() || (started.seen && !state.runOutput.isRunning && !state.debug.isActive)
        }, timeout: 240, run: {
            started.pressed = false
            started.seen = false
            prepare()
            var config = state.runConfig
            config.args = [scenario]
            state.runConfigs = RunConfig.merged(config, into: state.runConfigs)
        }, check: {
            started.pressed ? check() : "\(Shortcuts.keys(for: "Debug › Debug") ?? "no shortcut") did not reach Debug › Debug"
        })
    }

    static func labKey(_ name: String, _ path: String, state: AppState, ready: @escaping () -> Bool, check: @escaping () -> String?) -> SelfTestStep {
        let key = DebugLabScratch()
        return SelfTestStep(name: name, wait: 0.5, until: { !key.pressed || ready() || !state.debug.isActive }, timeout: 60, run: {
            key.pressed = SelfTestShortcut.press(path, in: SelfTestKeys.mainWindow)
        }, check: {
            key.pressed ? check() : "\(Shortcuts.keys(for: path) ?? "no shortcut") did not reach \(path)"
        })
    }

    static func labStop(_ name: String, state: AppState, e: SelfTestEditor, scratch: DebugLabScratch) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { !state.debug.isActive }, timeout: 30, run: {
            SelfTestShortcut.press("Debug › Stop", in: SelfTestKeys.mainWindow)
        }, check: {
            if scratch.line > 0 {
                state.toggleBreakpoint(path: scratch.path, line: scratch.line)
                scratch.line = 0
            }
            return e.expect(
                !state.debug.isActive && state.debug.breakpoints.isEmpty,
                "state \(state.debug.state) marks \(marks(state))"
            )
        })
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
