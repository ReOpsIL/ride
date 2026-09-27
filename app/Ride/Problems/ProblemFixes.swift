import AppKit

extension AppState {
    func applyDiagnosticFix(_ diag: StoredDiagnostic, fix: StoredFix) {
        openDiagnostic(diag)
        let wanted = URL(fileURLWithPath: diag.path).standardizedFileURL.path
        EditorShowing.when(path: wanted) { view in
            IntentionActions.apply(fix: fix, to: view)
        }
    }
}

enum EditorShowing {
    static let interval = 0.05
    static let attempts = 60

    static func when(path: String, remaining: Int = attempts, _ work: @escaping (RideTextView) -> Void) {
        if let view = EditorPanes.shared.focusedView,
           view.hooks.binding?()?.document.fileURL?.standardizedFileURL.path == path
        {
            work(view)
            return
        }
        guard remaining > 0 else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            when(path: path, remaining: remaining - 1, work)
        }
    }
}
