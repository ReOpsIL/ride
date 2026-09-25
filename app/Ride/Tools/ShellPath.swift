import Foundation

enum ShellPath {
    private static let lock = NSLock()
    private static var cached: String?

    static let fallbackDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        ("~/.cargo/bin" as NSString).expandingTildeInPath,
    ]

    static var value: String {
        lock.lock()
        defer { lock.unlock() }
        if let cached {
            return cached
        }
        let resolved = merged(login: loginShellPath(), inherited: ProcessInfo.processInfo.environment["PATH"])
        cached = resolved
        return resolved
    }

    static var directories: [String] {
        value.components(separatedBy: ":")
    }

    static func prime() {
        DispatchQueue.global(qos: .utility).async {
            _ = value
        }
    }

    static func merged(login: String?, inherited: String?, fallback: [String] = fallbackDirectories) -> String {
        let listed = [login, inherited].compactMap { $0 }.flatMap { $0.components(separatedBy: ":") }
        var seen = Set<String>()
        let ordered = (listed + fallback).filter { !$0.isEmpty && seen.insert($0).inserted }
        return ordered.joined(separator: ":")
    }

    private static func loginShellPath() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard FileManager.default.isExecutableFile(atPath: shell) else {
            return nil
        }
        let (output, success) = ProcessRun.capture(shell, ["-lc", "printf '%s' \"$PATH\""])
        guard success else {
            return nil
        }
        return output.components(separatedBy: .newlines).last { $0.contains("/") }
    }
}
