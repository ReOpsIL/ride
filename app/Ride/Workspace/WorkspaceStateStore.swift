import CryptoKit
import Foundation

final class WorkspaceStateStore {
    private let delay: TimeInterval = 0.5
    private let supportDir: URL
    private var work: DispatchWorkItem?

    init(supportDir: URL? = nil) {
        if let supportDir {
            self.supportDir = supportDir
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.supportDir = base.appendingPathComponent("Ride")
        }
    }

    func fileURL(for root: URL) -> URL {
        let digest = SHA256.hash(data: Data(root.standardizedFileURL.path.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return supportDir.appendingPathComponent("workspaces/\(name).json")
    }

    func load(root: URL) -> WorkspaceState? {
        guard let data = try? Data(contentsOf: fileURL(for: root)) else {
            return nil
        }
        return WorkspaceState.decode(data)
    }

    func scheduleSave(_ state: WorkspaceState, root: URL) {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.save(state, root: root)
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func save(_ state: WorkspaceState, root: URL) {
        work?.cancel()
        work = nil
        let url = fileURL(for: root)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
