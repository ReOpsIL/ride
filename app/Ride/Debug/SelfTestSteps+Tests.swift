import AppKit

extension SelfTestSteps {
    static let staleTestLine = "test util::ride_stale_test ... ok"

    static func runTests(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run tests", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            state.runAction(.test)
        }, check: {
            let tree = TestRunStore.shared.tree
            return e.expect(
                state.showTests && tree.passed == 1 && tree.failed == 0
                    && tree.rows.first?.name == "counts_one" && tree.rows.first?.suite == "util",
                "passed \(tree.passed) failed \(tree.failed) rows \(tree.rows.map(\.id)) status \(state.runOutput.status ?? "nil")"
            )
        })
    }

    static func testStopAndRerun(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "test stop and rerun", wait: 0.5, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 240, run: {
            state.runAction(.test)
            scratch.staleRunId = state.runOutput.runId
            state.runAction(.test)
            state.runOutput.append(staleTestLine, runId: scratch.staleRunId)
            scratch.staleShown = state.runOutput.text.contains(staleTestLine)
        }, check: {
            let tree = TestRunStore.shared.tree
            return e.expect(
                tree.passed == 1 && tree.failed == 0
                    && !scratch.staleShown
                    && !tree.rows.contains { $0.name.contains("ride_stale") },
                "passed \(tree.passed) failed \(tree.failed) rows \(tree.rows.map(\.name)) stale shown \(scratch.staleShown) status \(state.runOutput.status ?? "nil")"
            )
        })
    }

    static func gutterRunMarkers(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "gutter run markers", wait: 0.5, run: {
            guard let view = e.view, let document = state.activeBuffer else {
                return
            }
            TestMarkers.refresh(document: document, view: view)
        }, check: {
            let gutter = (e.view?.enclosingScrollView?.superview as? EditorHostView)?.gutter
            let markers = gutter?.runMarkers ?? [:]
            return e.expect(
                markers.count == 1 && markers[8]?.name == "main" && markers[8]?.framework == nil,
                "markers \(markers.map { "\($0.key):\($0.value.name)" })"
            )
        })
    }
}
