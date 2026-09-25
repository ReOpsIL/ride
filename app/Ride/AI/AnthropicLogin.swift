import Foundation

enum AnthropicLogin {
    static let installCommand = "brew install anthropics/tap/ant"
    private static let candidates = ["/opt/homebrew/bin/ant", "/usr/local/bin/ant", NSHomeDirectory() + "/go/bin/ant"]
    private static let lock = NSLock()
    private static var cached: (token: String, at: Date)?

    static var executable: String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func status(done: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let profile = run(["auth", "status"], timeout: 10).flatMap(activeProfile)
            DispatchQueue.main.async {
                done(profile)
            }
        }
    }

    static func login(done: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = run(["auth", "login"], timeout: 300)
            lock.lock()
            cached = nil
            lock.unlock()
            DispatchQueue.main.async {
                done(output != nil)
            }
        }
    }

    static func accessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached, Date().timeIntervalSince(cached.at) < 300 {
            return cached.token
        }
        guard let output = run(["auth", "print-credentials", "--access-token"], timeout: 30) else {
            return nil
        }
        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.contains(" ") else {
            return nil
        }
        cached = (token, Date())
        return token
    }

    static func forgetToken() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    private static func activeProfile(_ output: String) -> String? {
        for line in output.split(separator: "\n") where line.hasPrefix("Active profile:") {
            let rest = line.dropFirst("Active profile:".count).trimmingCharacters(in: .whitespaces)
            return rest.split(separator: " ").first.map(String.init)
        }
        return nil
    }

    private static func run(_ arguments: [String], timeout: TimeInterval) -> String? {
        guard let executable else {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ShellPath.value
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }
}
