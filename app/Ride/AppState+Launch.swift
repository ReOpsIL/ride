import Foundation

extension AppState {
    static func launchFolder() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--open"), args.indices.contains(i + 1) else {
            return nil
        }
        let url = URL(fileURLWithPath: args[i + 1])
        return WorkspaceFS.isDirectory(url) ? url : nil
    }
}
