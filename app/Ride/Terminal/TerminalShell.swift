import Foundation

enum TerminalShell {
    static let fallback = "/bin/zsh"

    static func executable() -> String {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        guard !shell.isEmpty, FileManager.default.isExecutableFile(atPath: shell) else {
            return fallback
        }
        return shell
    }

    static func arguments() -> [String] {
        ["-l"]
    }

    static func environment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env.removeValue(forKey: "TERM_PROGRAM")
        return env.map { "\($0.key)=\($0.value)" }
    }
}
