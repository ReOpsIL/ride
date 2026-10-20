import AppKit

extension SelfTestSteps {
    static let labNestedCall = "nested = offset("
    static let labDiscount = "reduced = amount - amount * percent / 100"
    static let labPriceBase = "750"

    static func labSteppingSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let file = lab.file("stepping")
        let atCall = { debugStopped(state) && state.debug.stoppedLine == scratch.line && stoppedFile(state) == (file as NSString).lastPathComponent }
        return [
            labBreakpoint("lab stepping breakpoint", state: state, e: e, file: file, anchor: labNestedCall, scratch: scratch),
            labDebug("lab stepping debug", state: state, scenario: "stepping", ready: atCall) {
                e.expect(atCall(), labWhere(state))
            },
            labCommand("lab step into", state: state, command: .stepIn, ready: { labTop(state, is: lab.steppedInto) }) {
                let caller = state.debugPanel.frames.dropFirst().first
                return e.expect(
                    labTop(state, is: lab.steppedInto) && caller?.line == scratch.line,
                    labWhere(state)
                )
            },
            labCommand("lab step out", state: state, command: .stepOut, ready: {
                debugStopped(state) && state.debugPanel.frames.first.map { !$0.name.contains(lab.steppedInto) } == true
            }) {
                e.expect(atCall() && labTop(state, is: lab.scenarioFrame("stepping")), labWhere(state))
            },
            labStop("lab stepping stop", state: state, e: e, scratch: scratch),
        ]
    }

    static func labStackSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        [
            labBreakpoint("lab stack breakpoint", state: state, e: e, file: lab.file("stack"), anchor: labDiscount, scratch: scratch),
            labDebug("lab stack frames", state: state, scenario: "stack", ready: {
                labTop(state, is: "discount") && state.debugPanel.frames.count >= lab.stackFrames.count
            }) {
                let names = labFrames(state)
                let matched = zip(lab.stackFrames, names).allSatisfy { expected, name in name.contains(expected) }
                return e.expect(
                    matched && names.count >= lab.stackFrames.count && state.debug.stoppedLine == scratch.line,
                    labWhere(state)
                )
            },
            labStackFrameLocals(state: state, e: e),
            labStop("lab stack stop", state: state, e: e, scratch: scratch),
        ]
    }

    private static func labStackFrameLocals(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "lab stack frame locals", wait: 0.5, until: { labLocal(state, "base") != nil }, timeout: 30, run: {
            guard let price = state.debugPanel.frames.dropFirst().first else {
                return
            }
            state.debugPanel.selectFrame(price.id)
        }, check: {
            let price = state.debugPanel.frames.dropFirst().first
            let base = labLocal(state, "base")
            return e.expect(
                price?.name.contains("price") == true && state.debugPanel.selectedFrame == price?.id && base == labPriceBase,
                "selected \(state.debugPanel.selectedFrame.map(String.init) ?? "nil") base \(base ?? "nil") " + labWhere(state)
            )
        })
    }
}
