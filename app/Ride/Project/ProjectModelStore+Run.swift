import Foundation

extension ProjectModelStore {
    var runTargets: [RunTarget] {
        guard let model else {
            return []
        }
        return model.targets.map { RunTarget($0, root: model.root) }
    }

    var runKind: RunProjectKind {
        RunProjectKind(model?.kind ?? .none)
    }

    var defaultRow: TargetRow? {
        selected ?? rows.first { $0.kind == .bin } ?? rows.first { $0.kind == .lib } ?? rows.first
    }

    var runTarget: RunTarget? {
        guard let row = defaultRow else {
            return nil
        }
        return runTargets.first { $0.name == row.name && $0.kind == row.kind }
    }
}
