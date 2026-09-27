import Foundation

extension AppState {
    func filesChanged(_ paths: [String]) {
        guard let root = workspaceRoot else {
            return
        }
        let batch = WatchPaths.classify(paths, root: root)
        if !batch.isEmpty {
            git.refresh(root: root)
        }
        guard !batch.sources.isEmpty else {
            return
        }
        reloadTree()
        diskChanged(paths: batch.sources)
        dropMissingClangDiagnostics()
        let change = ManifestWatch.change(batch.sources, root: root)
        if change.reloadProject {
            projectModel.reload()
        }
        if change.reindexCargo {
            scheduleCargoReindex(root)
        }
    }

    private func scheduleCargoReindex(_ root: URL) {
        cargoWork?.cancel()
        let work = DispatchWorkItem {
            IndexerProcess.run(project: root, indexDir: RideEngineClient.shared.indexDir)
        }
        cargoWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
}
