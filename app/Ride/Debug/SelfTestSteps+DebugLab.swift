import AppKit

final class DebugLabScratch {
    var path = ""
    var line: UInt32 = 0
    var sequence = 0
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
            + labThreadSteps(state: state, e: e, lab: lab, scratch: scratch)
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

    static func labBreakpoint(_ name: String, state: AppState, e: SelfTestEditor, file: String, anchor: String, condition: String? = nil, scratch: DebugLabScratch) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.6, until: {
            guard scratch.line == 0, e.text.contains(anchor) else {
                return scratch.line > 0
            }
            e.focus()
            e.place(on: anchor)
            scratch.line = UInt32(e.caretLine)
            scratch.path = debugPath(state) ?? ""
            state.toggleBreakpoint(path: scratch.path, line: scratch.line)
            if let condition {
                state.debug.breakpoints.edit(path: scratch.path, line: scratch.line, condition: condition, hitCondition: nil)
                state.breakpointsChanged(path: scratch.path)
            }
            return true
        }, timeout: 15, run: {
            scratch.line = 0
            openRelative(state, file)
        }, check: {
            let mark = state.debug.breakpoints.mark(path: scratch.path, line: scratch.line)
            return e.expect(
                scratch.path.hasSuffix(file) && marks(state) == [scratch.line] && mark?.condition == condition,
                "\(scratch.path):\(scratch.line) marks \(marks(state)) condition \(mark?.condition ?? "nil")"
            )
        })
    }

    static func labDebug(
        _ name: String,
        state: AppState,
        scenario: String,
        prepare: @escaping () -> Void = {},
        ready: @escaping () -> Bool,
        check: @escaping () -> String?
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { ready() || (!state.runOutput.isRunning && !state.debug.isActive) }, timeout: 240, run: {
            prepare()
            var config = state.runConfig
            config.args = [scenario]
            state.runConfigs = RunConfig.merged(config, into: state.runConfigs)
            state.startDebug()
        }, check: check)
    }

    static func labCommand(_ name: String, state: AppState, command: DebugCommand, ready: @escaping () -> Bool, check: @escaping () -> String?) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { ready() || !state.debug.isActive }, timeout: 60, run: {
            state.debugCommand(command)
        }, check: check)
    }

    static func labStop(_ name: String, state: AppState, e: SelfTestEditor, scratch: DebugLabScratch) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { !state.debug.isActive }, timeout: 30, run: {
            state.stopDebug()
            state.toggleBreakpoint(path: scratch.path, line: scratch.line)
        }, check: {
            e.expect(
                !state.debug.isActive && state.debug.breakpoints.isEmpty,
                "state \(state.debug.state) marks \(marks(state))"
            )
        })
    }

    static func labFrames(_ state: AppState) -> [String] {
        state.debugPanel.frames.map(\.name)
    }

    static func labTop(_ state: AppState, is function: String) -> Bool {
        debugStopped(state) && state.debugPanel.frames.first?.name.contains(function) == true
    }

    static func labLocal(_ state: AppState, _ name: String) -> String? {
        state.debugPanel.tree.rows.first { $0.node.name == name }?.node.value
    }

    static func labWhere(_ state: AppState) -> String {
        "state \(state.debug.state) at \(stoppedFile(state)):\(state.debug.stoppedLine) frames \(labFrames(state).prefix(8)) "
            + SelfTestRunScratch.status(state)
    }
}
