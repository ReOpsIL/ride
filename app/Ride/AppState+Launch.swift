import Foundation

extension AppState {
    static func launchTarget() -> URL? {
        guard let path = LaunchArguments.value(after: "--open") else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func openLaunchTarget(_ url: URL) {
        if WorkspaceFS.isDirectory(url) {
            open(url)
        } else {
            openPath(url)
        }
    }
}
