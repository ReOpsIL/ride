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

    func runTestMarker(_ marker: TestMarkerRow, path: String?) {
        guard let framework = marker.framework else {
            runMain(path: path)
            return
        }
        runTests(names: [marker.name], framework: framework)
    }

    func runMain(path: String?) {
        let owner = path.flatMap { projectModel.runTarget(owning: $0) }
        guard let request = runRequest(.run, target: owner) else {
            showNotice("Nothing to run for this file")
            return
        }
        startRun(request)
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
        TestRunStore.shared.framework ?? TestSession.framework(for: projectModel.runKind)
    }

    private func runTests(names: [String], framework: TestMarkerFramework) {
        guard let base = testBase(framework),
              let argv = TestFilterCommand.argv(names: names, framework: framework, base: base)
        else {
            showNotice("Nothing to test for this project")
            return
        }
        let plan = runPlan(.test)
        let cwd = plan?.cwd ?? activeProjectRoot?.path
        startRun(RunRequest(
            invocation: RunInvocation(argv: argv, workingDir: cwd, env: plan?.env ?? [:]),
            session: .tests(framework: framework)
        ))
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
