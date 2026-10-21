import AppKit

extension SelfTestSteps {
    static let labDiscount = "reduced = amount - amount * percent / 100"
    static let labOrderFields = ["id": "7", "quantity": "3", "unit_price": "250"]

    static func labStackSteps(state: AppState, e: SelfTestEditor, lab: DebugLab, scratch: DebugLabScratch) -> [SelfTestStep] {
        let file = lab.file("stack")
        return [
            labBreakpoint("lab stack breakpoint", state: state, e: e, file: file, anchor: labDiscount, scratch: scratch),
            labDebug("lab stack frames", state: state, scenario: "stack", ready: {
                labTop(state, is: "discount") && state.debugPanel.frames.count >= lab.stackFrames.count && labFollows(state, e: e)
            }) {
                let names = labFrames(state)
                let matched = zip(lab.stackFrames, names).allSatisfy { expected, name in name.contains(expected) }
                return e.expect(matched && labShows(state, e: e, file: file, line: scratch.line), labWhere(state))
            },
            labEvaluate(state: state, e: e),
            labSelectFrame("lab stack frame locals", index: 1, state: state, e: e, ready: { labLocal(state, "base") != nil }) {
                labLocal(state, "base") == "750" ? nil : "base \(labLocal(state, "base") ?? "nil")"
            },
            labSelectFrame("lab stack checkout locals", index: 2, state: state, e: e, ready: { labExpandOrder(state, lab: lab) }) {
                let fields = labOrderValues(state, lab: lab)
                return fields == labOrderFields ? nil : "order \(fields)"
            },
            labStepOutTo(lab.scenarioFrame("stack"), state: state, e: e, scratch: scratch),
            labKey("lab stack step over", "Debug › Step Over", state: state, ready: { labLocal(state, "receipt") == "810" }) {
                e.expect(labLocal(state, "receipt") == "810" && labFollows(state, e: e), "receipt \(labLocal(state, "receipt") ?? "nil") " + labWhere(state))
            },
            labStop("lab stack stop", state: state, e: e, scratch: scratch),
        ]
    }

    private static func labEvaluate(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let evaluation = DebugEvaluation.shared
        let opened = DebugLabScratch()
        return SelfTestStep(name: "lab stack evaluate", wait: 0.5, until: {
            guard state.debugPanel.showEvaluate else {
                return false
            }
            if !opened.pressed {
                opened.pressed = true
                evaluation.expression = "amount * 2"
                evaluation.evaluate(in: state.debugPanel)
            }
            return evaluation.result.contains("1500")
        }, timeout: 30, run: {
            SelfTestShortcut.press("Debug › Evaluate Expression…", in: SelfTestKeys.mainWindow)
        }, check: {
            let result = evaluation.result
            evaluation.close(state.debugPanel)
            evaluation.expression = ""
            return e.expect(opened.pressed && result.contains("1500") && !state.debugPanel.showEvaluate, "opened \(opened.pressed) result '\(result)'")
        })
    }

    static func labSelectFrame(_ name: String, index: Int, state: AppState, e: SelfTestEditor, ready: @escaping () -> Bool, check: @escaping () -> String?) -> SelfTestStep {
        let frame = { state.debugPanel.frames.dropFirst(index).first }
        return SelfTestStep(name: name, wait: 0.5, until: ready, timeout: 30, run: {
            if let id = frame()?.id {
                state.debugPanel.selectFrame(id)
            }
        }, check: {
            guard let target = frame(), let path = target.path else {
                return "no frame \(index): " + labWhere(state)
            }
            let jumped = labShows(state, e: e, file: (path as NSString).lastPathComponent, line: target.line)
            let selected = state.debugPanel.selectedFrame == target.id
            return e.expect(selected && jumped, "selected \(selected) jumped \(jumped) " + labWhere(state)) ?? check()
        })
    }

    private static func labOrderNode(_ state: AppState, lab: DebugLab) -> VariableNode? {
        let name = lab.language == .cpp ? "this" : "order"
        return state.debugPanel.tree.rows.first { $0.node.name == name }?.node
    }

    private static func labExpandOrder(_ state: AppState, lab: DebugLab) -> Bool {
        guard let node = labOrderNode(state, lab: lab) else {
            return false
        }
        if !state.debugPanel.tree.isExpanded(node.id) {
            state.debugPanel.toggle(VariableRow(node: node, depth: 0, expanded: false))
        }
        return labOrderValues(state, lab: lab) == labOrderFields
    }

    private static func labOrderValues(_ state: AppState, lab: DebugLab) -> [String: String] {
        guard let node = labOrderNode(state, lab: lab) else {
            return [:]
        }
        let children = state.debugPanel.tree.loaded(node.id)
        return labOrderFields.keys.reduce(into: [:]) { found, field in
            found[field] = children.first { $0.name == field || $0.name == field + "_" }?.value
        }
    }

    private static func labStepOutTo(_ function: String, state: AppState, e: SelfTestEditor, scratch: DebugLabScratch) -> SelfTestStep {
        let settled = {
            debugStopped(state) && state.debugPanel.frames.first.map { $0.line == state.debug.stoppedLine } == true
        }
        return SelfTestStep(name: "lab stack step out", wait: 0.5, until: {
            if settled(), labTop(state, is: function) {
                return true
            }
            if settled(), DebugController.shared.stopSequence != scratch.sequence, scratch.count < 5 {
                scratch.sequence = DebugController.shared.stopSequence
                scratch.count += 1
                SelfTestShortcut.press("Debug › Step Out", in: SelfTestKeys.mainWindow)
            }
            return !state.debug.isActive
        }, timeout: 60, run: {
            scratch.sequence = 0
            scratch.count = 0
        }, check: {
            e.expect(labTop(state, is: function) && scratch.count == 3 && labFollows(state, e: e), "step outs \(scratch.count) " + labWhere(state))
        })
    }
}
