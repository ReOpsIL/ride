import AppKit

extension AppState {
    func toggleTests() {
        showTests.toggle()
    }

    func beginTestRun(runId: Int, argv: [String], framework: TestMarkerFramework? = nil) {
        guard let framework = framework ?? TestSession.framework(for: projectModel.runKind) else {
            TestSession.shared.cancel()
            return
        }
        showTests = true
        TestSession.shared.begin(
            runId: runId,
            framework: framework,
            command: argv.joined(separator: " ")
        )
    }

    func runTestMarker(_ marker: TestMarkerRow) {
        guard let framework = marker.framework else {
            runAction(.run)
            return
        }
        runTests(names: [marker.name], framework: framework)
    }

    func rerunFailedTests() {
        guard let framework = rerunFramework() else {
            showNotice("No test framework for this project")
            return
        }
        runTests(names: TestRunStore.shared.tree.failedNames(framework: framework), framework: framework)
    }

    var canRerunFailedTests: Bool {
        guard let framework = rerunFramework() else {
            return false
        }
        return !TestRunStore.shared.tree.failedNames(framework: framework).isEmpty
    }

    private func rerunFramework() -> TestMarkerFramework? {
        TestRunStore.shared.framework ?? markerFramework()
    }

    private func runTests(names: [String], framework: TestMarkerFramework) {
        guard let base = testBase(framework),
              let argv = TestFilterCommand.argv(names: names, framework: framework, base: base)
        else {
            showNotice("Nothing to test for this project")
            return
        }
        let plan = runPlan(.test)
        let cwd = plan?.cwd ?? workspaceRoot?.path
        guard let runId = runInOutput(RunInvocation(argv: argv, workingDir: cwd, env: plan?.env ?? [:])) else {
            return
        }
        BuildSession.shared.cancel()
        SingleFileChain.shared.cancel()
        beginTestRun(runId: runId, argv: argv, framework: framework)
    }

    private func markerFramework() -> TestMarkerFramework? {
        switch projectModel.runKind {
        case .cargo:
            return .cargo
        case .cmake:
            return .ctest
        case .make, .compileDb, .none:
            return nil
        }
    }

    private func testBase(_ framework: TestMarkerFramework) -> [String]? {
        switch framework {
        case .cargo, .ctest:
            guard let argv = runPlan(.test)?.argv else {
                return nil
            }
            guard let separator = argv.firstIndex(of: "--") else {
                return argv
            }
            return Array(argv.prefix(upTo: separator))
        case .googleTest, .catch2:
            return runTarget?.run
        }
    }
}
