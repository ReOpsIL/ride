import Foundation

enum CheckScope: Equatable {
    case cargo(root: String)
    case clangProject
    case file(String)

    var source: String {
        switch self {
        case .cargo(let root): "cargo:" + root
        case .clangProject: "clang-project"
        case .file(let path): path
        }
    }
}

extension DiagnosticStore {
    mutating func replace(_ scope: CheckScope, with items: [StoredDiagnostic]) {
        switch scope {
        case .cargo(let root):
            replaceCargo(root: root, items)
        case .clangProject:
            replaceAllClang(from: scope.source, with: items)
        case .file:
            replace(from: scope.source, with: items)
        }
    }
}
