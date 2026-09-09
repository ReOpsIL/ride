import Foundation

final class GitStatusService: ObservableObject {
    @Published var dirty: Set<String> = []
    @Published var dirtyDirs: Set<String> = []
    private var work: DispatchWorkItem?
    private let queue = DispatchQueue(label: "dev.ride.git")
    private var generation = 0

    func refresh(root: URL, delay: TimeInterval = 1) {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.run(root: root)
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func clear() {
        dirty = []
        dirtyDirs = []
    }

    func isDirty(relative: String, isDirectory: Bool) -> Bool {
        isDirectory ? dirtyDirs.contains(relative) : dirty.contains(relative)
    }

    private func run(root: URL) {
        generation += 1
        let gen = generation
        queue.async { [weak self] in
            let output = Self.porcelain(root: root)
            DispatchQueue.main.async {
                guard let self, gen == self.generation else {
                    return
                }
                let files = output.map(GitStatus.parse) ?? []
                self.dirty = files
                self.dirtyDirs = GitStatus.parents(of: files)
            }
        }
    }

    private static func porcelain(root: URL) -> String? {
        let git = URL(fileURLWithPath: "/usr/bin/git")
        guard FileManager.default.isExecutableFile(atPath: git.path),
              FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path)
        else {
            return nil
        }
        let proc = Process()
        proc.executableURL = git
        proc.arguments = ["-C", root.path, "status", "--porcelain", "--untracked-files=all"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }
}
