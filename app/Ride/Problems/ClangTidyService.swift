import Foundation

enum ClangTidyService {
    static func run(file: URL, root: URL, completion: @escaping ([StoredDiagnostic]) -> Void) {
        guard hasConfig(root: root), let tool = ProcessLookup.url(for: "clang-tidy", workingDir: root.path) else {
            return
        }
        let path = file.path
        let buildDir = compileDir(root: root)
        DispatchQueue.global(qos: .utility).async {
            let output = invoke(tool: tool, path: path, buildDir: buildDir)
            let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let items = ClangTidyParse.diagnostics(output: output, path: path, text: text)
            DispatchQueue.main.async { completion(items) }
        }
    }

    static func hasConfig(root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(".clang-tidy").path)
    }

    private static func compileDir(root: URL) -> String? {
        for relative in ["", "build", "build/Debug"] {
            let dir = relative.isEmpty ? root : root.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("compile_commands.json").path) {
                return dir.path
            }
        }
        return nil
    }

    private static func invoke(tool: URL, path: String, buildDir: String?) -> String {
        let process = Process()
        process.executableURL = tool
        var arguments = [path, "-quiet"]
        if let buildDir {
            arguments += ["-p", buildDir]
        }
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
