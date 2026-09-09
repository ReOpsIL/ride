import Foundation

enum WorkspaceFS {
    static func skipName(_ name: String) -> Bool {
        name == "target" || name == ".git"
    }

    static func children(of url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        return names
            .filter { !skipName($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .compactMap { name in
                let child = url.appendingPathComponent(name).standardizedFileURL
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: child.path, isDirectory: &isDir) else {
                    return nil
                }
                return FileNode(url: child, isDirectory: isDir.boolValue)
            }
    }

    static func parentDir(for url: URL, isDirectory: Bool) -> URL {
        isDirectory ? url : url.deletingLastPathComponent()
    }

    static func relativePath(root: URL, file: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        if filePath == rootPath {
            return "."
        }
        if filePath.hasPrefix(rootPath + "/") {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        return file.lastPathComponent
    }
}

final class FileNode: Identifiable, ObservableObject {
    var id: URL { url }
    let url: URL
    let name: String
    let isDirectory: Bool
    @Published var children: [FileNode] = []
    private var loaded = false

    init(url: URL, isDirectory: Bool) {
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
    }

    func loadChildren() {
        guard isDirectory else {
            return
        }
        if !loaded {
            loaded = true
            children = WorkspaceFS.children(of: url)
        }
    }

    func reload() {
        loaded = false
        loadChildren()
    }
}
