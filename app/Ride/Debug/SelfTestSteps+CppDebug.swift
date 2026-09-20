import AppKit

final class CppDebugScratch {
    var line: UInt32 = 0
    var path = ""
    var vector: VariableNode?
}

extension SelfTestSteps {
    static let cppBreakpointBody = "return PI * radius_ * radius_;"
    static let cppCallerBody = "out << this->name_"

    static func cppDebugSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        guard DeveloperMode.isEnabled else {
            return [cppDebugSkipped()]
        }
        let scratch = CppDebugScratch()
        return [
            cppDebugPrep(state: state, e: e),
            cppDebugBreakpoint(state: state, e: e, scratch: scratch),
            cppDebugBuild(state: state, e: e),
            cppDebugStopped(state: state, e: e, scratch: scratch),
            cppDebugFrames(state: state, e: e, scratch: scratch),
            cppDebugVector(state: state, e: e, scratch: scratch),
            cppDebugStepOut(state: state, e: e, scratch: scratch),
            cppDebugDisconnect(state: state, e: e),
        ]
    }

    private static func cppDebugSkipped() -> SelfTestStep {
        SelfTestStep(name: "cpp debug (skipped: developer mode disabled)", wait: 0.1, run: {}, check: { nil })
    }

    private static func cppDebugPrep(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "cpp debug prep", wait: 1.2, run: {
            state.saveAll()
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            e.focus()
        }, check: {
            e.expect(e.text.contains(cppBreakpointBody), "no \(cppBreakpointBody)")
        })
    }

    private static func cppDebugBreakpoint(state: AppState, e: SelfTestEditor, scratch: CppDebugScratch) -> SelfTestStep {
        SelfTestStep(name: "cpp debug breakpoint", wait: 0.4, run: {
            e.focus()
            e.place(on: cppBreakpointBody)
            scratch.line = UInt32(e.caretLine)
            scratch.path = debugPath(state) ?? ""
            state.toggleBreakpointAtCaret()
        }, check: {
            e.expect(
                scratch.line > 0 && !scratch.path.isEmpty && marks(state) == [scratch.line],
                "line \(scratch.line) marks \(marks(state))"
            )
        })
    }

    private static func cppDebugBuild(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "cpp debug build", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            state.runAction(.build)
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0",
                "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(240))"
            )
        })
    }

    private static func cppDebugStopped(state: AppState, e: SelfTestEditor, scratch: CppDebugScratch) -> SelfTestStep {
        SelfTestStep(name: "cpp debug stops in Circle::area", wait: 0.5, until: {
            state.debug.isStopped && state.debug.stoppedLine > 0
        }, timeout: 30, run: {
            state.startDebug()
        }, check: {
            e.expect(
                state.debug.isStopped && state.debug.stoppedLine == scratch.line,
                "line \(state.debug.stoppedLine) stopped \(state.debug.isStopped)"
            )
        })
    }

    private static func cppDebugFrames(state: AppState, e: SelfTestEditor, scratch: CppDebugScratch) -> SelfTestStep {
        SelfTestStep(name: "cpp debug frames", wait: 0.4, until: {
            state.debugPanel.frames.contains { $0.name.contains("Circle::area") }
        }, timeout: 30, run: {}, check: {
            let frames = state.debugPanel.frames
            return e.expect(
                frames.first?.name.contains("Circle::area") == true && frames.first?.line == scratch.line,
                "frames \(frames.map { "\($0.name):\($0.line)" })"
            )
        })
    }

    private static func cppDebugVector(state: AppState, e: SelfTestEditor, scratch: CppDebugScratch) -> SelfTestStep {
        SelfTestStep(name: "cpp debug vector local", wait: 0.4, until: {
            guard let node = vectorLocal(state) else {
                return false
            }
            scratch.vector = node
            if state.debugPanel.tree.isLoaded(node.id) {
                return true
            }
            if !state.debugPanel.tree.isExpanded(node.id) {
                state.debugPanel.toggle(VariableRow(node: node, depth: 1, expanded: false))
            }
            return false
        }, timeout: 30, run: {
            guard let frame = state.debugPanel.frames.first(where: { $0.name.contains("main") }) else {
                return
            }
            state.debugPanel.selectFrame(frame.id, jump: false)
        }, check: {
            guard let node = scratch.vector else {
                return "no std::vector local in \(state.debugPanel.tree.rows.map(\.node.name))"
            }
            let children = state.debugPanel.tree.loaded(node.id)
            return e.expect(
                !children.isEmpty && node.value.contains("size="),
                "\(node.name) \(node.typeName ?? "nil") \(node.value) children \(children.count)"
            )
        })
    }

    private static func cppDebugStepOut(state: AppState, e: SelfTestEditor, scratch: CppDebugScratch) -> SelfTestStep {
        SelfTestStep(name: "cpp debug step out", wait: 0.5, until: {
            state.debug.isStopped && state.debug.stoppedLine > 0 && state.debug.stoppedLine != scratch.line
        }, timeout: 30, run: {
            state.toggleBreakpoint(path: scratch.path, line: scratch.line)
            state.debugCommand(.stepOut)
        }, check: {
            let text = e.line(Int(state.debug.stoppedLine))
            return e.expect(
                state.debug.stoppedLine != scratch.line && text.contains(cppCallerBody),
                "line \(state.debug.stoppedLine): \(text)"
            )
        })
    }

    private static func cppDebugDisconnect(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "cpp debug stop", wait: 0.5, until: { !state.debug.isActive }, timeout: 30, run: {
            state.stopDebug()
        }, check: {
            e.expect(
                !state.debug.isActive && state.debug.breakpoints.isEmpty,
                "active \(state.debug.isActive) marks \(marks(state))"
            )
        })
    }

    private static func vectorLocal(_ state: AppState) -> VariableNode? {
        state.debugPanel.tree.rows.first { $0.node.typeName?.contains("vector") == true }?.node
    }
}
