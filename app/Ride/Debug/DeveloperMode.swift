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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["-status"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else {
            return "unavailable"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? "unavailable"
    }
}
