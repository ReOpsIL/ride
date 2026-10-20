import AppKit

extension SelfTestSteps {
    static let labRecursiveCall = "below = factorial(n - 1)"
    static let labRecursionCondition = "n == 3"
    static let labRecursionDepth = 6
    static let labRecursionResult = "8! = 40320"
    static let labWorkerBody = "contribution = "
    static let labThrowFilter = "cpp_throw"

    static func labRecursionSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let depth = { labFrames(state).filter { $0.contains("factorial") }.count }
        return [
            labBreakpoint(
                "lab recursion breakpoint",
                state: state,
                e: e,
                file: lab.file("recursion"),
                anchor: labRecursiveCall,
                condition: labRecursionCondition,
                scratch: scratch
            ),
            labDebug("lab recursion condition", state: state, scenario: "recursion", ready: {
                labTop(state, is: "factorial") && labLocal(state, "n") != nil
            }) {
                e.expect(
                    state.debug.stoppedLine == scratch.line && depth() == labRecursionDepth && labLocal(state, "n") == "3",
                    "depth \(depth()) n \(labLocal(state, "n") ?? "nil") " + labWhere(state)
                )
            },
            labCommand("lab recursion stops once", state: state, command: .continue, ready: { debugStopped(state) }) {
                e.expect(
                    !state.debug.isActive && state.runOutput.text.contains(labRecursionResult),
                    "stopped again or did not finish: " + labWhere(state)
                )
            },
            labStop("lab recursion stop", state: state, e: e, scratch: scratch),
        ]
    }

    static func labThreadSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        [
            labBreakpoint("lab threads breakpoint", state: state, e: e, file: lab.file("threads"), anchor: labWorkerBody, scratch: scratch),
            labDebug("lab threads debug", state: state, scenario: "threads", ready: { labTop(state, is: "work") }) {
                e.expect(labTop(state, is: "work") && state.debug.stoppedLine == scratch.line, labWhere(state))
            },
            labThreadPicker(state: state, e: e, lab: lab, scratch: scratch),
            labThreadSwitch(state: state, e: e, lab: lab),
            labStop("lab threads stop", state: state, e: e, scratch: scratch),
        ]
    }

    private static func labThreadPicker(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> SelfTestStep {
        let threads = { state.debugPanel.threads.map(\.name) }
        let listed = {
            threads().count > DebugLab.workers && lab.workerNames.allSatisfy { worker in threads().contains { $0.contains(worker) } }
        }
        return SelfTestStep(name: "lab threads picker", wait: 0.5, until: {
            if listed() {
                return true
            }
            guard debugStopped(state), !state.debugPanel.frames.isEmpty, DebugController.shared.stopSequence != scratch.sequence else {
                return !state.debug.isActive
            }
            state.debugCommand(.continue)
            scratch.sequence = DebugController.shared.stopSequence
            return false
        }, timeout: 60, run: {
            scratch.sequence = DebugController.shared.stopSequence
        }, check: {
            e.expect(
                listed() && labTop(state, is: "work") && state.debugPanel.selectedThread == DebugController.shared.stoppedThread,
                "threads \(threads()) " + labWhere(state)
            )
        })
    }

    private static func labThreadSwitch(state: AppState, e: SelfTestEditor, lab: DebugLab) -> SelfTestStep {
        let spawner = lab.scenarioFrame("threads")
        let other = { state.debugPanel.threads.first { $0.id != DebugController.shared.stoppedThread } }
        return SelfTestStep(name: "lab threads select", wait: 0.5, until: {
            labFrames(state).contains { $0.contains(spawner) }
        }, timeout: 30, run: {
            if let thread = other() {
                state.debugPanel.selectThread(thread.id)
            }
        }, check: {
            e.expect(
                state.debugPanel.selectedThread == other()?.id && labFrames(state).contains { $0.contains(spawner) },
                "selected \(state.debugPanel.selectedThread.map(String.init) ?? "nil") " + labWhere(state)
            )
        })
    }

    static func labThrowSteps(state: AppState, e: SelfTestEditor, scratch: DebugLabScratch) -> [SelfTestStep] {
        [
            labDebug("lab cpp throw filter", state: state, scenario: "faults", prepare: {
                scratch.filter = DebugFilters.shared.toggles.first { $0.id == labThrowFilter }?.enabled
                DebugFilters.shared.set(id: labThrowFilter, enabled: true)
            }, ready: { labTop(state, is: "__cxa_throw") }) {
                e.expect(
                    scratch.filter != nil && labTop(state, is: "__cxa_throw") && labFrames(state).contains { $0.contains("parse_quantity") },
                    "filter \(scratch.filter.map(String.init) ?? "missing") " + labWhere(state)
                )
            },
            SelfTestStep(name: "lab cpp throw stop", wait: 0.5, until: { !state.debug.isActive }, timeout: 30, run: {
                state.stopDebug()
                DebugFilters.shared.set(id: labThrowFilter, enabled: scratch.filter ?? false)
            }, check: {
                e.expect(!state.debug.isActive, "state \(state.debug.state)")
            }),
        ]
    }
}
