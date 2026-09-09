import Foundation

enum IndexerProcess {
    static func helperURL() -> URL? {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ride-engine")
    }

    static func run(project: URL, indexDir: URL, force: Bool = false) {
        guard let bin = helperURL(), FileManager.default.isExecutableFile(atPath: bin.path) else {
            return
        }
        try? FileManager.default.createDirectory(at: indexDir, withIntermediateDirectories: true)
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = [
            "--project-path", project.path,
            "--index-dir", indexDir.path,
            "index",
        ] + (force ? ["--force"] : [])
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return
        }
    }
}
