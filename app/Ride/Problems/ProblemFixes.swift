import AppKit

extension AppState {
    func applyDiagnosticFix(_ diag: StoredDiagnostic, fix: StoredFix) {
        openDiagnostic(diag)
        let wanted = URL(fileURLWithPath: diag.path).standardizedFileURL.path
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let view = EditorPanes.shared.focusedView,
                  let document = view.hooks.binding?()?.document,
                  document.fileURL?.standardizedFileURL.path == wanted
            else {
                return
            }
            IntentionActions.apply(fix: fix, to: view)
        }
    }
}
