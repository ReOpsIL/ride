import Foundation

extension AppState {
    static func launchFolder() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--open"), args.indices.contains(i + 1),
           let url = folder(args[i + 1])
        {
            return url
        }
        if let path = ProcessInfo.processInfo.environment["RIDE_OPEN"] {
            return folder(path)
        }
        return nil
    }

    private static func folder(_ path: String) -> URL? {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return url
    }
}
