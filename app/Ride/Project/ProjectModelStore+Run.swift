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

    func runTarget(owning path: String) -> RunTarget? {
        guard let model else {
            return nil
        }
        let wanted = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        let root = URL(fileURLWithPath: model.root)
        let owner = model.targets.first { target in
            target.run != nil && target.sources.contains { source in
                URL(fileURLWithPath: source, relativeTo: root).resolvingSymlinksInPath().path == wanted
            }
        }
        return owner.map { RunTarget($0, root: model.root) }
    }

    var runTarget: RunTarget? {
        guard let row = defaultRow else {
            return nil
        }
        return runTargets.first { $0.name == row.name && $0.kind == row.kind }
    }
}
