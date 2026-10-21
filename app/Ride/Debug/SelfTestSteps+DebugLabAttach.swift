import Foundation

final class DebugLabFork {
    var child: UInt32 = 0
    var waitName = ""

    func childPid(in text: String) -> UInt32? {
        pid(after: "fork: child pid ", in: text)
    }

    func parentStarted(in text: String) -> Bool {
        pid(after: "fork: parent pid ", in: text) != nil
    }

    private func pid(after marker: String, in text: String) -> UInt32? {
        guard let range = text.range(of: marker, options: .backwards) else {
            return nil
        }
        return UInt32(text[range.upperBound...].prefix { $0.isNumber })
    }
}

extension SelfTestSteps {
    static let labForkBody = "squared = round * round"
    static let labChildFunction = "child_work"

    static func labAttachSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let fork = DebugLabFork()
        let output = { state.runOutput.text }
        return [
            labBreakpoint("lab fork breakpoint", state: state, e: e, file: lab.file("fork"), anchor: labForkBody, scratch: scratch),
            labForkBuild(state: state, e: e),
            labForkRun("lab fork run", state: state, e: e, delay: 0) { fork.childPid(in: output()) != nil },
            labAttachPid(state: state, e: e, fork: fork, scratch: scratch),
            labDetach("lab attach pid stop", state: state, e: e, fork: fork, scratch: scratch, last: false),
            labForkRun("lab fork run delayed", state: state, e: e, delay: 6) { fork.parentStarted(in: output()) },
            labAttachWait(state: state, e: e, fork: fork, scratch: scratch),
            labDetach("lab attach wait stop", state: state, e: e, fork: fork, scratch: scratch, last: true),
        ]
    }

    private static func labForkBuild(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let build = SelfTestMenuPress("Run › Build")
        let started = DebugLabScratch()
        return SelfTestStep(name: "lab fork build", wait: 0.5, until: {
            guard build.pressWhenEnabled() else {
                return false
            }
            started.seen = started.seen || state.runOutput.isRunning
            return started.seen && !state.runOutput.isRunning
        }, timeout: 240, run: {
            build.reset()
            started.seen = false
        }, check: {
            e.expect(build.pressed && started.seen && !state.runOutput.isRunning, SelfTestRunScratch.status(state))
        })
    }

    private static func labForkRun(_ name: String, state: AppState, e: SelfTestEditor, delay: Int, ready: @escaping () -> Bool) -> SelfTestStep {
        let run = SelfTestMenuPress("Run › Run")
        return SelfTestStep(name: name, wait: 0.5, until: run.until(ready), timeout: 240, run: {
            run.reset()
            var config = state.runConfig
            config.args = ["fork", String(delay)]
            state.runConfigs = RunConfig.merged(config, into: state.runConfigs)
        }, check: {
            e.expect(run.pressed && ready(), "pressed \(run.pressed) " + SelfTestRunScratch.status(state))
        })
    }

    private static func labAttachPid(state: AppState, e: SelfTestEditor, fork: DebugLabFork, scratch: DebugLabScratch) -> SelfTestStep {
        let model = state.attachModel
        let press = SelfTestMenuPress("Debug › Attach to Process…")
        return SelfTestStep(name: "lab attach pid", wait: 0.5, until: {
            guard press.pressWhenEnabled() else {
                return false
            }
            if model.visible, model.rows.contains(where: { $0.pid == fork.child }) {
                model.selection = fork.child
                model.attach()
            }
            return labStoppedInChild(state, e: e, scratch: scratch)
        }, timeout: 60, run: {
            press.reset()
            fork.child = fork.childPid(in: state.runOutput.text) ?? 0
        }, check: {
            e.expect(press.pressed && fork.child > 0 && labStoppedInChild(state, e: e, scratch: scratch), "child \(fork.child) " + labWhere(state))
        })
    }

    private static func labAttachWait(state: AppState, e: SelfTestEditor, fork: DebugLabFork, scratch: DebugLabScratch) -> SelfTestStep {
        let model = state.attachModel
        let press = SelfTestMenuPress("Debug › Attach to Process…")
        return SelfTestStep(name: "lab attach wait", wait: 0.5, until: {
            guard press.pressWhenEnabled() else {
                return false
            }
            if model.visible {
                model.mode = .waitFor
                fork.waitName = model.waitName
                model.attach()
            }
            fork.child = fork.childPid(in: state.runOutput.text) ?? 0
            return fork.child > 0 && labStoppedInChild(state, e: e, scratch: scratch)
        }, timeout: 60, run: {
            press.reset()
            fork.waitName = ""
        }, check: {
            e.expect(
                press.pressed && fork.waitName.hasSuffix(DebugLab.target) && fork.child > 0 && labStoppedInChild(state, e: e, scratch: scratch),
                "waited for '\(fork.waitName)' child \(fork.child) " + labWhere(state)
            )
        })
    }

    private static func labDetach(_ name: String, state: AppState, e: SelfTestEditor, fork: DebugLabFork, scratch: DebugLabScratch, last: Bool) -> SelfTestStep {
        let alive = { fork.child > 0 && kill(pid_t(fork.child), 0) == 0 }
        let detached = DebugLabScratch()
        return SelfTestStep(name: name, wait: 0.5, until: {
            if !detached.seen, !state.debug.isActive {
                detached.seen = true
                detached.pressed = alive()
                kill(pid_t(fork.child), SIGTERM)
            }
            return detached.seen && !state.runOutput.isRunning
        }, timeout: 30, run: {
            detached.seen = false
            detached.pressed = false
            SelfTestShortcut.press("Debug › Stop", in: SelfTestKeys.mainWindow)
        }, check: {
            if last, scratch.line > 0 {
                state.toggleBreakpoint(path: scratch.path, line: scratch.line)
                scratch.line = 0
            }
            return e.expect(
                detached.pressed && !state.debug.isActive && !state.runOutput.isRunning && state.runOutput.text.contains("exited with"),
                "child alive after Stop \(detached.pressed) " + labWhere(state)
            )
        })
    }

    private static func labStoppedInChild(_ state: AppState, e: SelfTestEditor, scratch: DebugLabScratch) -> Bool {
        labTop(state, is: labChildFunction) && state.debug.stoppedLine == scratch.line && labFollows(state, e: e)
    }
}
