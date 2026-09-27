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
}
