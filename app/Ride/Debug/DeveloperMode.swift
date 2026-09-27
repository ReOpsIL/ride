import Foundation

enum DeveloperMode {
    static let tool = "/usr/sbin/DevToolsSecurity"

    static var isEnabled: Bool {
        status().contains("enabled")
    }

    static func status() -> String {
        guard FileManager.default.isExecutableFile(atPath: tool) else {
            return "unavailable"
        }
        return ProcessRun.output(URL(fileURLWithPath: tool), ["-status"], includeErrors: false)?.text ?? "unavailable"
    }
}
