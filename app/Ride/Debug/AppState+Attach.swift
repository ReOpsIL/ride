import Foundation

extension AppState {
    var attachModel: AttachModel {
        AttachModel.shared
    }

    func observeAttach() {
        attachModel.onRefresh = { [weak self] in
            self?.loadProcesses()
        }
        attachModel.onAttach = { [weak self] choice in
            self?.attachDebugger(choice)
        }
    }

    func showAttachSheet() {
        guard !debug.isActive else {
            return
        }
        attachModel.open(waitName: debugLaunch()?.program)
    }

    func attachDebugger(_ choice: AttachChoice) {
        guard !debug.isActive else {
            return
        }
        showRunOutput = true
        debug.attach(DebugAttach(
            process: choice.process,
            cwd: activeProjectRoot?.path,
            exceptionFilters: DebugFilters.shared.enabledIds
        ))
    }

    private func loadProcesses() {
        let own = UInt32(ProcessInfo.processInfo.processIdentifier)
        let started = RideEngineClient.shared.withEngine(qos: .userInitiated) { engine in
            (try? engine.debugProcesses()) ?? []
        } then: { [weak self] listed in
            self?.attachModel.load(listed.map(ProcessRow.init), excluding: own)
        }
        if !started {
            attachModel.load([], excluding: own)
        }
    }
}

private extension AttachChoice {
    var process: AttachProcess {
        switch self {
        case let .pid(pid, program):
            return .pid(pid: pid, program: program)
        case let .waitFor(program):
            return .waitFor(program: program)
        }
    }
}

private extension ProcessRow {
    init(_ process: DebugProcess) {
        self.init(pid: process.pid, parent: process.parent, name: process.name, path: process.path)
    }
}
