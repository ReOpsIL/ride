import AppKit

extension SelfTestSteps {
    static let labWorkerBody = "contribution = "

    static func labThreadSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        [
            labBreakpoint("lab threads breakpoint", state: state, e: e, file: lab.file("threads"), anchor: labWorkerBody, scratch: scratch),
            labDebug("lab threads debug", state: state, scenario: "threads", ready: { labTop(state, is: "work") && labFollows(state, e: e) }) {
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
            scratch.sequence = DebugController.shared.stopSequence
            SelfTestShortcut.press("Debug › Continue", in: SelfTestKeys.mainWindow)
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

    static func labHeartbeatSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let beats = { state.runOutput.text.components(separatedBy: "/40").count - 1 }
        let pause = SelfTestMenuPress("Debug › Pause")
        let inHeartbeat = { debugStopped(state) && labFrames(state).contains { $0.contains(lab.scenarioFrame("heartbeat")) } }
        return [
            labDebug("lab heartbeat debug", state: state, scenario: "heartbeat", ready: { state.debug.isRunning && beats() >= 2 }) {
                e.expect(state.debug.isRunning && beats() >= 2, "beats \(beats()) " + labWhere(state))
            },
            SelfTestStep(name: "lab heartbeat pause", wait: 0.5, until: pause.until(inHeartbeat), timeout: 30, run: {
                pause.reset()
            }, check: {
                e.expect(
                    pause.pressed && inHeartbeat() && !labTop(state, is: lab.scenarioFrame("heartbeat")),
                    "pressed \(pause.pressed) " + labWhere(state)
                )
            }),
            SelfTestStep(name: "lab heartbeat continue", wait: 0.5, until: { state.debug.isRunning && beats() >= scratch.count + 2 }, timeout: 30, run: {
                scratch.count = beats()
                SelfTestShortcut.press("Debug › Continue", in: SelfTestKeys.mainWindow)
            }, check: {
                e.expect(state.debug.isRunning && beats() >= scratch.count + 2, "beats \(scratch.count) → \(beats()) " + labWhere(state))
            }),
            SelfTestStep(name: "lab heartbeat stop", wait: 0.5, until: { !state.debug.isActive }, timeout: 30, run: {
                SelfTestShortcut.press("Debug › Stop", in: SelfTestKeys.mainWindow)
            }, check: {
                e.expect(!state.debug.isActive && beats() < 40, "beats \(beats()) " + labWhere(state))
            }),
        ]
    }
}
