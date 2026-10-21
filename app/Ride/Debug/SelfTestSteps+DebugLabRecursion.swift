import AppKit

extension SelfTestSteps {
    static let labRecursiveCall = "below = factorial(n - 1)"
    static let labRecursionResult = "8! = 40320"
    static let labLoopBody = "sum += square"
    static let labLoopWatches = ["sum": "4324", "i * 2": "48"]

    static func labRecursionSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let depth = { labFrames(state).filter { $0.contains("factorial") }.count }
        return [
            labBreakpoint("lab recursion breakpoint", state: state, e: e, file: lab.file("recursion"), anchor: labRecursiveCall, scratch: scratch),
            labBreakpointDialog("lab recursion condition dialog", state: state, e: e, condition: "n == 3", hits: "", scratch: scratch),
            labDebug("lab recursion condition", state: state, scenario: "recursion", ready: {
                labTop(state, is: "factorial") && labLocal(state, "n") != nil && labFollows(state, e: e)
            }) {
                e.expect(
                    state.debug.stoppedLine == scratch.line && depth() == 6 && labLocal(state, "n") == "3",
                    "depth \(depth()) n \(labLocal(state, "n") ?? "nil") " + labWhere(state)
                )
            },
            labSelectFrame("lab recursion frame n", index: 2, state: state, e: e, ready: { labLocal(state, "n") == "5" }) {
                labLocal(state, "n") == "5" ? nil : "n \(labLocal(state, "n") ?? "nil")"
            },
            labKey("lab recursion stops once", "Debug › Continue", state: state, ready: { debugStopped(state) }) {
                e.expect(
                    !state.debug.isActive && state.runOutput.text.contains(labRecursionResult),
                    "stopped again or did not finish: " + labWhere(state)
                )
            },
            labStop("lab recursion stop", state: state, e: e, scratch: scratch),
        ]
    }

    static func labLoopSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        [
            labBreakpoint("lab loops breakpoint", state: state, e: e, file: lab.file("loops"), anchor: labLoopBody, scratch: scratch),
            labBreakpointDialog("lab loops hit count dialog", state: state, e: e, condition: "", hits: "25", scratch: scratch),
            labDebug("lab loops hit count", state: state, scenario: "loops", ready: { labLocal(state, "i") != nil && labFollows(state, e: e) }) {
                e.expect(
                    state.debug.stoppedLine == scratch.line && labLocal(state, "i") == "24" && labLocal(state, "square") == "576",
                    "i \(labLocal(state, "i") ?? "nil") square \(labLocal(state, "square") ?? "nil") " + labWhere(state)
                )
            },
            labWatches(state: state, e: e),
            labStop("lab loops stop", state: state, e: e, scratch: scratch),
        ]
    }

    private static func labWatches(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let values = { labLoopWatches.keys.reduce(into: [String: String]()) { found, key in found[key] = labWatch(state, key) } }
        return SelfTestStep(name: "lab loops watches", wait: 0.5, until: { values().count == labLoopWatches.count }, timeout: 30, run: {
            labLoopWatches.keys.sorted().forEach(state.debugPanel.addWatch)
        }, check: {
            let found = values()
            labLoopWatches.keys.forEach { state.debugPanel.removeWatch(id: $0) }
            return e.expect(found == labLoopWatches && state.debugPanel.watches.isEmpty, "watches \(found)")
        })
    }
}
