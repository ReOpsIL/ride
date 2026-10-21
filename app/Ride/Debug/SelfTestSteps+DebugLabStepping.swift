import AppKit

extension SelfTestSteps {
    static let labNestedCall = "nested = offset("

    static func labSteppingSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let file = lab.file("stepping")
        let at = { (offset: UInt32) in debugStopped(state) && state.debug.stoppedLine == scratch.line + offset && labTop(state, is: lab.scenarioFrame("stepping")) }
        return [
            labBreakpoint("lab stepping breakpoint", state: state, e: e, file: file, anchor: labNestedCall, scratch: scratch),
            labDebug("lab stepping debug", state: state, scenario: "stepping", ready: { at(0) && labFollows(state, e: e) }) {
                e.expect(at(0) && labShows(state, e: e, file: file, line: scratch.line), labWhere(state))
            },
            labKey("lab step into", "Debug › Step Into", state: state, ready: { labTop(state, is: lab.steppedInto) && labFollows(state, e: e) }) {
                let caller = state.debugPanel.frames.dropFirst().first
                return e.expect(
                    labTop(state, is: lab.steppedInto) && caller?.line == scratch.line && labShows(state, e: e, file: file, line: state.debug.stoppedLine),
                    labWhere(state)
                )
            },
            labKey("lab step out", "Debug › Step Out", state: state, ready: { at(0) && labFollows(state, e: e) }) {
                e.expect(at(0) && labShows(state, e: e, file: file, line: scratch.line), labWhere(state))
            },
            labKey("lab step over", "Debug › Step Over", state: state, ready: { at(1) && labFollows(state, e: e) }) {
                e.expect(at(1) && labShows(state, e: e, file: file, line: scratch.line + 1), labWhere(state))
            },
            labStop("lab stepping stop", state: state, e: e, scratch: scratch),
        ]
    }
}
