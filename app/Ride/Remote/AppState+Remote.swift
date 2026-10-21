import AppKit

extension AppState {
    func editRemote() {
        guard workspaceRoot != nil else {
            return
        }
        remoteEditor.load(remoteToolchain)
        showRemoteSheet = true
    }

    func saveRemote() {
        remoteEditor.stopTest()
        remoteToolchain = remoteEditor.draft
        showRemoteSheet = false
    }

    func cancelRemote() {
        remoteEditor.stopTest()
        showRemoteSheet = false
    }

    func testRemote() {
        guard let root = workspaceRoot?.standardizedFileURL.path else {
            return
        }
        remoteEditor.test(RemoteLaunch.link(for: remoteEditor.draft, localRoot: root))
    }

    func activeRemote() -> RemoteLink? {
        guard remoteToolchain.enabled, !remoteToolchain.remoteRoot.isEmpty, let root = workspaceRoot?.standardizedFileURL.path else {
            return nil
        }
        return RemoteLaunch.link(for: remoteToolchain, localRoot: root)
    }

    func bindRemoteRun() {
        runOutput.remoteStart = { [weak self] invocation, id, hooks in
            guard let self, let link = self.activeRemote() else {
                return false
            }
            self.remoteRun.start(link: link, invocation: invocation, runId: id, hooks: hooks)
            return true
        }
        runOutput.remoteStop = { [weak self] in
            self?.remoteRun.stop()
        }
    }

    func syncThenDebug(_ launch: DebugLaunch) {
        guard let link = activeRemote() else {
            debug.launch(launch)
            return
        }
        let label = link.user.isEmpty ? link.host : "\(link.user)@\(link.host)"
        guard let id = runOutput.hold(label) else {
            showNotice("A process is already running")
            return
        }
        remoteRun.sync(link: link, runId: id, hooks: debugHooks(id, link, launch))
    }

    private func debugHooks(_ id: Int, _ link: RemoteLink, _ launch: DebugLaunch) -> RemoteRunHooks {
        RemoteRunHooks(
            onLine: { [weak self] runId, line in
                self?.runOutput.append(line, runId: runId)
            },
            onCommand: { [weak self] command in
                self?.runOutput.showCommand(command)
            },
            onFinish: { [weak self] finish in
                guard let self else {
                    return
                }
                self.runOutput.release(finish, id: id)
                guard finish.succeeded else {
                    return
                }
                if let message = self.debug.launchRemote(link, launch) {
                    self.showNotice(message)
                }
            }
        )
    }
}
