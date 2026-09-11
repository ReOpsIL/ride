import AppKit

extension SelfTestSteps {
    static func splitHeaderSource(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "split header source", wait: 0.8, run: {
            if let pair = headerSourcePair(state: state) {
                state.openFile(pair.source)
                state.toggleSplit()
                state.switchHeaderSource()
                return
            }
            if let other = state.buffers.first(where: { $0.id != state.activeID }) {
                state.openInSplit(other.id)
            } else {
                state.toggleSplit()
            }
        }, check: {
            let paths = state.paneLayout.panes.compactMap { state.buffer($0.activeID)?.fileURL?.path }
            return e.expect(Set(paths).count == 2, "panes \(paths)")
        })
    }

    private static func headerSourcePair(state: AppState) -> (source: URL, header: URL)? {
        guard let root = state.workspaceRoot else {
            return nil
        }
        let named = (
            source: root.appendingPathComponent("src/geo.cpp"),
            header: root.appendingPathComponent("include/geo.h")
        )
        if FileManager.default.fileExists(atPath: named.source.path),
           FileManager.default.fileExists(atPath: named.header.path)
        {
            return named
        }
        guard let current = state.activeBuffer?.fileURL, let sibling = SiblingSource.existing(for: current) else {
            return nil
        }
        let ext = current.pathExtension.lowercased()
        if SiblingSource.sources.contains(ext) {
            return (current, sibling)
        }
        return (sibling, current)
    }
}
