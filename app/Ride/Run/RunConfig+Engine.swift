import Foundation

extension RunProjectKind {
    init(_ kind: ProjectKind) {
        switch kind {
        case .cargo: self = .cargo
        case .cMake: self = .cmake
        case .make: self = .make
        case .compileDb: self = .compileDb
        case .none: self = .none
        }
    }

    var engineKind: ProjectKind {
        switch self {
        case .cargo: .cargo
        case .cmake: .cMake
        case .make: .make
        case .compileDb: .compileDb
        case .none: .none
        }
    }
}

extension RunConfig {
    static func `default`(target: Target, model: ProjectModel) -> RunConfig {
        let dir = target.workingDir.isEmpty ? model.root : target.workingDir
        return RunConfig(target: target.name, workingDir: dir)
    }

    func flags(for kind: ProjectKind) -> (env: [String: String], args: [String]) {
        flags(for: RunProjectKind(kind))
    }

    func requiresNightly(for kind: ProjectKind) -> Bool {
        requiresNightly(for: RunProjectKind(kind))
    }
}
