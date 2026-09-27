import Foundation

enum TreeFileError: LocalizedError {
    case exists(String)
    case createFailed(String)

    var errorDescription: String? {
        switch self {
        case let .exists(name): return "\(name) already exists"
        case let .createFailed(name): return "\(name) could not be created"
        }
    }
}

enum TreeFileOps {
    static func createFile(named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw TreeFileError.exists(name)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
            throw TreeFileError.createFailed(name)
        }
        return url
    }

    static func createFolder(named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw TreeFileError.exists(name)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func rename(_ url: URL, to name: String) throws -> URL {
        let dest = url.deletingLastPathComponent().appendingPathComponent(name)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }

    static func duplicate(_ url: URL) throws -> URL {
        let dest = duplicateURL(for: url) { FileManager.default.fileExists(atPath: $0.path) }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    static func duplicateURL(for url: URL, exists: (URL) -> Bool) -> URL {
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        var index = 1
        while true {
            let stem = index == 1 ? "\(base) copy" : "\(base) copy \(index)"
            let candidate = ext.isEmpty ? dir.appendingPathComponent(stem) : dir.appendingPathComponent(stem).appendingPathExtension(ext)
            if !exists(candidate) {
                return candidate
            }
            index += 1
        }
    }
}
