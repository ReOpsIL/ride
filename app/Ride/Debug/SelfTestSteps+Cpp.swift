import AppKit

extension SelfTestSteps {
    static func cpp(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
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
            commentLine(e: e),
            uncommentLine(e: e),
            engineReady(e: e),
            matchingBrace(e: e),
            fold(e: e),
            unfold(e: e),
            cppQuickDefinitionOpen(state: state, e: e),
            cppQuickDefinition(state: state, e: e),
            peekCleanup(),
            completeStatementPrep(e: e),
            completeStatement(e: e),
            completeStatementCleanup(e: e),
            goToLine(state: state, e: e, file: file),
            back(state: state, e: e, file: file),
            forward(state: state, e: e, file: file),
            zoomIn(state: state, e: e, scratch: scratch),
            zoomReset(state: state, e: e),
        ] + workspaceOpenSecond(state: state, e: e, file: file, scratch: scratch) + [
            workspaceRestore(state: state, e: e, file: file),
            workspaceSnapshotAfterOpen(state: state, e: e),
            headerSourceSwitch(state: state, e: e),
            runFileError(state: state, e: e),
            recompileFile(state: state, e: e, relative: "src/shapes.cpp"),
            generatePrep(state: state, e: e, scratch: scratch),
            generateConstructor(e: e),
            generateGetters(e: e),
            generateCleanup(e: e, scratch: scratch),
        ] + liveSteps(state: state, e: e) + cppExtract(state: state, e: e, scratch: scratch)
            + cppRefactor(e: e, scratch: scratch) + cppDebugSteps(state: state, e: e)
            + moveStatementSteps(
                state: state,
                e: e,
                scratch: scratch,
                file: "src/shapes.cpp",
                source: "void ride_move() {\n    int move_a = 1;\n    int move_b = 2;\n}\n",
                first: "int move_a = 1;",
                second: "int move_b = 2;"
            )
    }
}
