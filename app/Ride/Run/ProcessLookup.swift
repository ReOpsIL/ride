import Foundation

enum ProcessLookup {
    static func url(for tool: String, workingDir: String?) -> URL? {
        if tool.contains("/") {
            if tool.hasPrefix("/") {
                return URL(fileURLWithPath: tool)
            }
            let base = workingDir ?? FileManager.default.currentDirectoryPath
            return URL(fileURLWithPath: (base as NSString).appendingPathComponent(tool))
        }
        for dir in ShellPath.directories {
            let candidate = (dir as NSString).appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
}
