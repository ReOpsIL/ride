import Foundation

extension AppState {
    func beginRename() {
        RenameController.shared.begin(state: self)
    }

    func resolveRenameURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        if let root = workspaceRoot {
            return root.appendingPathComponent(path).standardizedFileURL
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }
}
