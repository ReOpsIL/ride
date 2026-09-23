import AppKit

extension SelfTestSteps {
    static func rust(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [setup(e: e, file: file, scratch: scratch)] + gutterSteps(state: state, e: e) + [findUsages(state: state, e: e)]
            + rustRun(state: state, e: e, scratch: scratch)
            + rustEdit(e: e, file: file, scratch: scratch)
            + rustSelect(e: e)
            + rustTools(state: state, e: e, file: file)
            + rustClose(state: state, e: e, file: file, scratch: scratch)
            + rustGenerate(e: e, scratch: scratch)
            + renameSteps(state: state, e: e)
            + rustExtract(e: e, scratch: scratch)
            + rustRefactor(e: e, scratch: scratch)
            + rustIntentions(e: e, scratch: scratch)
            + breakpointShiftSteps(state: state, e: e)
            + [callHierarchy(state: state, e: e)]
            + [codeVision(state: state, e: e)]
            + safeDeleteSteps(state: state, e: e, scratch: scratch)
            + openURLSteps(state: state, e: e)
            + sampleSteps(state: state, e: e)
            + moveStatementSteps(
                state: state,
                e: e,
                scratch: scratch,
                file: "src/main.rs",
                source: "fn _ride_move() {\n    let move_a = 1;\n    let move_b = 2;\n}\n",
                first: "let move_a = 1;",
                second: "let move_b = 2;"
            )
            + [typeAtEnd(state: state, e: e)]
    }

    private static func findUsages(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "find usages", wait: 0.3, until: {
            if state.usages.running {
                return false
            }
            if state.usages.finished, state.usages.name == "record", state.usages.total == 2 {
                return true
            }
            e.caret(line: 10, column: 14)
            state.findUsages()
            return false
        }, timeout: 30, run: {
            e.caret(line: 10, column: 14)
        }, check: {
            e.expect(
                state.showUsages && state.usages.name == "record" && state.usages.total == 2,
                "name \(state.usages.name) total \(state.usages.total)"
            )
        })
    }
}
