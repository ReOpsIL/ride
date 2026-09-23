import Foundation

final class ProjectModelStore: ObservableObject {
    @Published private(set) var projects: [ProjectModel] = []
    @Published private(set) var rows: [TargetRow] = []
    @Published private(set) var kindLabel = ""
    @Published private(set) var profiles: [String] = []
    @Published private(set) var notice: String?
    @Published private(set) var selected: TargetRow?
    @Published var profile = ""
    @Published private(set) var model: ProjectModel?

    var onChange: (() -> Void)?
    private(set) var workspace: URL?
    private var fetches = 0
    private var wanted: String?
    private var focusedPath: String?

    var groups: [TargetGroup] { TargetRows.grouped(rows) }

    func load(workspace root: URL) {
        if workspace != root {
            clear()
        }
        workspace = root
        fetch(root: root, reload: false)
    }

    func reload() {
        guard let workspace else {
            return
        }
        fetch(root: workspace, reload: true)
    }

    func clear() {
        workspace = nil
        projects = []
        focusedPath = nil
        wanted = nil
        activate(nil)
    }

    func select(_ row: TargetRow?) {
        wanted = row?.name
        selected = row
        onChange?()
    }

    func restoreSelection(_ name: String?) {
        wanted = name
        applySelection()
    }

    func focus(file: URL?) {
        guard let path = file?.standardizedFileURL.path else {
            return
        }
        focusedPath = path
        if let owner = owner(ofPath: path), owner.root != model?.root {
            activate(owner)
        }
    }

    func choose(root: String) {
        if let project = projects.first(where: { $0.root == root }), project.root != model?.root {
            activate(project)
        }
    }

    func owner(of url: URL) -> ProjectModel? {
        owner(ofPath: url.standardizedFileURL.path)
    }

    func title(_ project: ProjectModel) -> String {
        ProjectOwner.title(root: project.root, workspace: workspace?.path ?? "")
    }

    private func owner(ofPath path: String) -> ProjectModel? {
        ProjectOwner.owner(of: path, roots: projects.map(\.root)).map { projects[$0] }
    }

    private func fetch(root: URL, reload: Bool) {
        guard let engine = RideEngineClient.shared.engine else {
            return
        }
        fetches += 1
        let fetch = fetches
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = try? reload
                ? engine.reloadWorkspaceProjects(root: root.path)
                : engine.workspaceProjects(root: root.path)
            DispatchQueue.main.async {
                guard let self, self.fetches == fetch, self.workspace == root, let found else {
                    return
                }
                self.apply(found)
            }
        }
    }

    private func apply(_ found: [ProjectModel]) {
        projects = found
        let keep = model.flatMap { current in found.first { $0.root == current.root } }
        activate(keep ?? focusedPath.flatMap(owner(ofPath:)) ?? found.first)
    }

    private func activate(_ project: ProjectModel?) {
        model = project
        rows = project?.targets.map(ProjectModelStore.row(from:)) ?? []
        kindLabel = project.map { ProjectModelStore.label($0.kind) } ?? ""
        profiles = project?.profiles ?? []
        notice = project?.notice
        if !profiles.contains(profile) {
            profile = profiles.first ?? ""
        }
        applySelection()
    }

    private func applySelection() {
        selected = wanted.flatMap { name in rows.first { $0.name == name } }
        onChange?()
    }

    private static func row(from target: Target) -> TargetRow {
        TargetRow(
            name: target.name,
            kind: TargetRowKind(target.kind),
            detail: target.build.joined(separator: " ")
        )
    }

    private static func label(_ kind: ProjectKind) -> String {
        switch kind {
        case .cargo: "Cargo"
        case .cMake: "CMake"
        case .make: "Make"
        case .compileDb: "Compile Database"
        case .none: ""
        }
    }
}
