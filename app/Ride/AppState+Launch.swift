import Foundation

extension AppState {
    static func launchFolder() -> URL? {
        guard let path = LaunchArguments.value(after: "--open") else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        return WorkspaceFS.isDirectory(url) ? url : nil
    }
}
