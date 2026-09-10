import Foundation

enum ToolInstaller {
    static func run(
        _ commands: [(String, String)],
        progress: @escaping (String, String, Bool) -> Void,
        done: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            for (name, command) in commands {
                let (output, success) = shell(command)
                DispatchQueue.main.async {
                    progress(name, output, success)
                }
            }
            DispatchQueue.main.async(execute: done)
        }
    }

    static func shell(_ command: String) -> (String, Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return ("\(error)", false)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (text.isEmpty ? (process.terminationStatus == 0 ? "done" : "exit \(process.terminationStatus)") : text, process.terminationStatus == 0)
    }
}
