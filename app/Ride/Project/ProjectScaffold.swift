import Foundation

struct ScaffoldFile: Equatable {
    let path: String
    let contents: String
}

struct ProjectScaffold: Equatable {
    var name: String
    var language: ProjectLanguage
    var buildSystem: ProjectBuildSystem
    var library = false

    static func validate(name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter a project name."
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Use letters, digits, '_' and '-' only."
        }
        if let first = trimmed.first, first.isNumber || first == "-" {
            return "The name must start with a letter or '_'."
        }
        return nil
    }

    var targetName: String {
        name.replacingOccurrences(of: "-", with: "_")
    }

    var files: [ScaffoldFile] {
        switch language {
        case .rust:
            rustFiles
        case .c, .cpp:
            buildSystem == .make ? makeFiles : cmakeFiles
        }
    }

    var mainFile: String {
        language == .rust && library ? "src/lib.rs" : language.mainFile
    }

    func write(to root: URL, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: root.path) {
            throw ScaffoldError.exists(root.lastPathComponent)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        for file in files {
            let url = root.appendingPathComponent(file.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
