import AppKit

extension AppState {
    func scheduleLiveCheck(_ buffer: BufferDocument, view: RideTextView) {
        guard prefs.checkOnSave else {
            return
        }
        if buffer.language.usesClang, let url = buffer.fileURL {
            CheckService.shared.scheduleLive(file: url, text: view.string)
        } else if buffer.language == .rust, let root = workspaceRoot {
            CheckService.shared.scheduleLiveCargo(root: root, clippy: prefs.useClippy)
        }
    }

    func runClangTidyOnSave(_ buffer: BufferDocument) {
        guard prefs.checkOnSave, buffer.language.usesClang,
              let url = buffer.fileURL, let root = workspaceRoot,
              ClangTidyService.hasConfig(root: root)
        else {
            return
        }
        let gen = CheckService.shared.bump(CheckService.livePrefix + url.path)
        ClangTidyService.run(file: url, root: root) { items in
            CheckService.shared.setLive(path: url.path, diagnostics: items, generation: gen)
        }
    }
}
