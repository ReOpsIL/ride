import Foundation

struct ProcessOutput: Equatable {
    let text: String
    let status: Int32
    let timedOut: Bool

    var succeeded: Bool {
        !timedOut && status == 0
    }
}

enum ProcessRun {
    static func output(
        _ executable: URL,
        _ arguments: [String],
        includeErrors: Bool = true,
        timeout: TimeInterval? = nil
    ) -> ProcessOutput? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = includeErrors ? pipe : FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let reader = PipeReader(pipe.fileHandleForReading)
        guard reader.wait(timeout: timeout) else {
            process.terminate()
            kill(process.processIdentifier, SIGKILL)
            _ = reader.wait(timeout: 0.5)
            return ProcessOutput(text: reader.text, status: -1, timedOut: true)
        }
        process.waitUntilExit()
        return ProcessOutput(text: reader.text, status: process.terminationStatus, timedOut: false)
    }

    static func capture(_ executable: String, _ arguments: [String], timeout: TimeInterval? = nil) -> (String, Bool) {
        guard let result = output(URL(fileURLWithPath: executable), arguments, timeout: timeout) else {
            return ("could not launch \(executable)", false)
        }
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty else {
            return (text, result.succeeded)
        }
        let summary = result.timedOut ? "timed out" : result.succeeded ? "done" : "exit \(result.status)"
        return (summary, result.succeeded)
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private final class PipeReader: @unchecked Sendable {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var data = Data()

    init(_ handle: FileHandle) {
        group.enter()
        DispatchQueue.global(qos: .utility).async { [self] in
            let read = handle.readDataToEndOfFile()
            lock.withLock { data = read }
            group.leave()
        }
    }

    var text: String {
        lock.withLock { String(decoding: data, as: UTF8.self) }
    }

    func wait(timeout: TimeInterval?) -> Bool {
        guard let timeout else {
            group.wait()
            return true
        }
        return group.wait(timeout: .now() + timeout) == .success
    }
}
