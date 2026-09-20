import Foundation

struct SampleProject: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let mainFile: String
}

enum SampleProjects {
    static let all = [
        SampleProject(id: "rust-demo", title: "Rust demo", summary: "Cargo crate with tests", mainFile: "src/main.rs"),
        SampleProject(id: "c-demo", title: "C demo", summary: "CMake and Makefile", mainFile: "src/main.c"),
        SampleProject(id: "cpp-demo", title: "C++ demo", summary: "CMake and Makefile", mainFile: "src/main.cpp"),
    ]

    static func sample(id: String) -> SampleProject? {
        all.first { $0.id == id }
    }

    static var directory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("samples", isDirectory: true)
    }

    static func source(_ sample: SampleProject) -> URL? {
        guard let directory else {
            return nil
        }
        let url = directory.appendingPathComponent(sample.id, isDirectory: true)
        return WorkspaceFS.isDirectory(url) ? url : nil
    }

    static var available: [SampleProject] {
        all.filter { source($0) != nil }
    }

    static func copy(
        _ sample: SampleProject,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let source = source(sample) else {
            throw SampleError.missing(sample.title)
        }
        let root = destination.standardizedFileURL
        if fileManager.fileExists(atPath: root.path) {
            throw ScaffoldError.exists(root.lastPathComponent)
        }
        try fileManager.createDirectory(
            at: root.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: source, to: root)
        return root
    }
}

enum SampleError: LocalizedError, Equatable {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case let .missing(title):
            "The \(title) sample is not bundled with this build of Ride."
        }
    }
}
