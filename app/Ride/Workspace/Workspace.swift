import Foundation

enum WorkspaceFS {
    static func skipName(_ name: String, showHidden: Bool) -> Bool {
        if name == "target" || name == ".git" {
            return true
        }
        return !showHidden && name.hasPrefix(".")
    }

    static func children(of url: URL, showHidden: Bool) -> [FileNode] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        return names
            .filter { !skipName($0, showHidden: showHidden) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .compactMap { name in
                let child = url.appendingPathComponent(name).standardizedFileURL
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: child.path, isDirectory: &isDir) else {
                    return nil
                }
                return FileNode(url: child, isDirectory: isDir.boolValue, showHidden: showHidden)
            }
    }

    static func parentDir(for url: URL, isDirectory: Bool) -> URL {
        isDirectory ? url : url.deletingLastPathComponent()
    }

    static func contains(root: URL?, file: URL) -> Bool {
        guard let root else {
            return false
        }
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        return filePath == rootPath || filePath.hasPrefix(rootPath + "/")
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
    let showHidden: Bool
    @Published var children: [FileNode] = []
    private var loaded = false

    init(url: URL, isDirectory: Bool, showHidden: Bool) {
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.showHidden = showHidden
    }

    func loadChildren() {
        guard isDirectory else {
            return
        }
        if !loaded {
            loaded = true
            children = WorkspaceFS.children(of: url, showHidden: showHidden)
        }
    }

    func reload() {
        loaded = false
        loadChildren()
    }
}
