import AppKit
import Combine

extension AppState {
    func configure() {
        prefs = PreferencesStore.load()
        recent = recents.load()
        menu.recent = recent
        ThemeStore.shared.apply(name: prefs.theme)
        watcher.handler = { [weak self] paths in
            self?.filesChanged(paths)
        }
        gitSink = git.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        projectModel.onChange = { [weak self] in
            self?.syncMenu()
        }
        runOutput.onChange = { [weak self] in
            self?.syncMenu()
        }
        AIAssistant.shared.onPanelChange = { [weak self] in
            self?.syncMenu()
        }
        observeDebug()
        runOutput.lineFilter = { runId, line in
            RunLineFilter.shown(runId: runId, line: line)
        }
        runOutput.onFinish = { [weak self] runId, finish in
            self?.runFinished(runId, finish)
        }
        CheckService.shared.onFinished = { [weak self] diagnostics in
            self?.checkFinished(diagnostics)
        }
        CheckService.shared.onLiveFinished = { [weak self] _ in
            self?.refreshDiagnosticUnderlines()
        }
        _ = RideEngineClient.shared
        EditorPanes.shared.onFocus = { [weak self] pane in
            self?.paneFocused(pane)
        }
        watchWorkspaceQuit()
        NotificationCenter.default.addObserver(
            forName: .rideOpenCatalog,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let url = note.object as? URL {
                self?.openFile(url, readOnly: CatalogPath.isCatalog(url))
            }
        }
        if let url = Self.launchFolder() {
            open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkCrashReports()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkTools()
        }
    }
}
