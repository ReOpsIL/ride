import AppKit

extension SelfTestSteps {
    static let breakpointLine: UInt32 = 10

    static func debugSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        var steps = [breakpointToggle(state: state, e: e), breakpointPersists(state: state, e: e)]
        steps += DeveloperMode.isEnabled ? liveDebug(state: state, e: e) : [debugSkipped()]
        steps.append(breakpointClear(state: state, e: e))
        steps += debugPanelSteps(state: state, e: e)
        return steps
    }

    private static func debugSkipped() -> SelfTestStep {
        SelfTestStep(name: "debug (skipped: developer mode disabled)", wait: 0.1, run: {}, check: { nil })
    }

    private static func breakpointToggle(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint toggle", wait: 0.4, run: {
            e.caret(line: Int(breakpointLine))
            state.toggleBreakpointAtCaret()
        }, check: {
            let gutter = (e.view?.enclosingScrollView?.superview as? EditorHostView)?.gutter
            return e.expect(
                marks(state) == [breakpointLine] && gutter?.breakpointLines[Int(breakpointLine)] == false,
                "marks \(marks(state)) gutter \(gutter?.breakpointLines ?? [:])"
            )
        })
    }

    private static func breakpointPersists(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint persists", wait: 0.6, run: {
            guard let data = try? JSONEncoder().encode(state.captureWorkspace()),
                  let loaded = WorkspaceState.decode(data)
            else {
                return
            }
            state.debug.breakpoints = Breakpoints()
            state.debug.breakpoints = loaded.breakpoints
            state.refreshBreakpointGutters()
        }, check: {
            e.expect(marks(state) == [breakpointLine], "marks \(marks(state))")
        })
    }

    private static func breakpointClear(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint clear", wait: 0.4, run: {
            guard let path = debugPath(state) else {
                return
            }
            state.toggleBreakpoint(path: path, line: breakpointLine)
        }, check: {
            e.expect(state.debug.breakpoints.isEmpty, "marks \(marks(state))")
        })
    }

    private static func liveDebug(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "debug", wait: 0.5, until: { state.debug.isStopped || !state.debug.isActive }, timeout: 240, run: {
                state.startDebug()
            }, check: {
                e.expect(
                    state.debug.isStopped && state.debug.stoppedLine == breakpointLine,
                    "line \(state.debug.stoppedLine) stopped \(state.debug.isStopped)"
                )
            }),
            SelfTestStep(name: "debug step over", wait: 0.5, until: { state.debug.isStopped && state.debug.stoppedLine != breakpointLine }, timeout: 60, run: {
                state.debugCommand(.next)
            }, check: {
                e.expect(
                    state.debug.stoppedLine == breakpointLine + 1,
                    "line \(state.debug.stoppedLine)"
                )
            }),
            SelfTestStep(name: "debug stop", wait: 0.5, until: { !state.debug.isActive }, timeout: 60, run: {
                state.stopDebug()
            }, check: {
                e.expect(!state.debug.isActive, "state still active")
            }),
        ]
    }

    private static func debugPath(_ state: AppState) -> String? {
        state.activeBuffer?.fileURL?.standardizedFileURL.path
    }

    private static func marks(_ state: AppState) -> Set<UInt32> {
        guard let path = debugPath(state) else {
            return []
        }
        return state.debug.breakpoints.lines(path: path)
    }
}
