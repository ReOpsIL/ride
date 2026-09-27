import Foundation

enum IndexerProcess {
    static func helperURL() -> URL? {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ride-engine")
    }

    @discardableResult
    static func run(project: URL, indexDir: URL, force: Bool = false, onExit: ((Int32) -> Void)? = nil) -> Bool {
        guard let bin = helperURL(), FileManager.default.isExecutableFile(atPath: bin.path) else {
            return false
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
        if let onExit {
            proc.terminationHandler = { finished in
                let status = finished.terminationStatus
                DispatchQueue.main.async { onExit(status) }
            }
        }
        do {
            try proc.run()
        } catch {
            return false
        }
        return true
    }
}
