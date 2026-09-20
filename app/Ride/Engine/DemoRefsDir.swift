import Foundation

enum DemoRefsDir {
    static let url: URL? = {
        guard DemoLaunch.isDemo else {
            return nil
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ride-refs-\(pid)", isDirectory: true)
    }()

    static func prepare() -> String? {
        guard let url else {
            return nil
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }

    static func remove() {
        guard let url else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }
}
