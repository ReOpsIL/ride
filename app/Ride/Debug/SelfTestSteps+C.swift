import AppKit

extension SelfTestSteps {
    static let cErrorLine = 29
    static let cErrorSuffix = " ride_bad_zz;"

    static func c(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            setup(e: e, file: file, scratch: scratch),
            indentKeeps(e: e, file: file, scratch: scratch),
            unindentKeeps(e: e, file: file, scratch: scratch),
            tabInserts(e: e, file: file, scratch: scratch),
            undoOneStep(e: e, file: file, scratch: scratch),
            duplicateLine(e: e, file: file, scratch: scratch),
            deleteLine(e: e, file: file, scratch: scratch),
            moveLineDown(e: e, file: file, scratch: scratch),
            moveLineUp(e: e, file: file, scratch: scratch),
            goToLine(state: state, e: e, file: file),
            back(state: state, e: e, file: file),
            forward(state: state, e: e, file: file),
            zoomIn(state: state, e: e, scratch: scratch),
            zoomReset(state: state, e: e),
        ] + workspaceOpenSecond(state: state, e: e, file: file, scratch: scratch) + [
            workspaceRestore(state: state, e: e, file: file),
            cBuild(state: state, e: e),
            cRun(state: state, e: e),
            buildDiagnostic(state: state, e: e, scratch: scratch, line: cErrorLine, suffix: cErrorSuffix),
            buildDiagnosticCleared(state: state, e: e, scratch: scratch, line: cErrorLine),
            recompileFile(state: state, e: e, relative: "src/main.c"),
        ]
    }

    private static func cBuild(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "c build", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            state.runAction(.build)
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.text.contains("Built target demo"),
                "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(240))"
            )
        })
    }

    private static func cRun(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "c run", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 120, run: {
            state.runAction(.run)
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.text.contains("distance 5.0, area 50.0"),
                "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(240))"
            )
        })
    }
}
