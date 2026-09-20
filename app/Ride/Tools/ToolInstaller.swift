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
        ProcessRun.capture("/bin/zsh", ["-lc", command])
    }
}
