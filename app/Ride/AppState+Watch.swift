import Foundation

extension AppState {
    func filesChanged(_ paths: [String]) {
        reloadTree()
        diskChanged(paths: paths)
        dropMissingClangDiagnostics()
        guard let root = workspaceRoot else {
            return
        }
        git.refresh(root: root)
        if ManifestWatch.touchesManifest(paths, root: root) {
            projectModel.reload()
        }
        if CargoWatch.touchesManifest(paths, root: root) {
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
