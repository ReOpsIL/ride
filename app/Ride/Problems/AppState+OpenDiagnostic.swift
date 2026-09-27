import Foundation

extension AppState {
    func openDiagnostic(_ diag: Diagnostic) {
        jumpToDiagnostic(path: diag.path, byteStart: diag.byteStart)
    }

    func openDiagnostic(_ diag: StoredDiagnostic) {
        ProblemsPanelModel.shared.selected = diag
        jumpToDiagnostic(path: diag.path, byteStart: diag.byteStart)
    }

    private func jumpToDiagnostic(path: String, byteStart: UInt32) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        openFile(url, at: .byte(byteStart), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }
}
