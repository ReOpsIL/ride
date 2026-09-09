import Foundation

enum HitNavigation {
    static func open(_ hit: CompletionHit, state: AppState) {
        guard let path = hit.sourcePath else {
            if let byte = hit.byteStart {
                state.jumpTo(byte: byte)
            }
            return
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let inside = WorkspaceFS.contains(root: state.workspaceRoot, file: url)
        state.pendingJump = hit.byteStart
        state.openFile(url, readOnly: !inside)
    }
}
