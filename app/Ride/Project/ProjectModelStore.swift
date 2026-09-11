import Foundation

final class ProjectModelStore: ObservableObject {
    @Published private(set) var rows: [TargetRow] = []
    @Published private(set) var kindLabel = ""
    @Published private(set) var profiles: [String] = []
    @Published private(set) var notice: String?
    @Published private(set) var selected: TargetRow?
    @Published var profile = ""

    var onChange: (() -> Void)?
    private var root: URL?
    private var loading = false

    var groups: [TargetGroup] { TargetRows.grouped(rows) }

    func load(root: URL) {
        self.root = root
        fetch(root: root, reload: false)
    }

    func reload() {
        guard let root else {
            return
        }
        fetch(root: root, reload: true)
    }

    func clear() {
        root = nil
        rows = []
        kindLabel = ""
        profiles = []
        profile = ""
        notice = nil
        selected = nil
        onChange?()
    }

    func select(_ row: TargetRow?) {
        selected = row
        onChange?()
    }

    private func fetch(root: URL, reload: Bool) {
        guard !loading, let engine = RideEngineClient.shared.engine else {
            return
        }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let model = try? reload
                ? engine.reloadProject(root: root.path)
                : engine.projectModel(root: root.path)
            DispatchQueue.main.async {
                self?.loading = false
                guard let self, self.root == root else {
                    return
                }
                self.apply(model)
            }
        }
    }

    private func apply(_ model: ProjectModel?) {
        guard let model else {
            return
        }
        rows = model.targets.map(ProjectModelStore.row(from:))
        kindLabel = ProjectModelStore.label(model.kind)
        profiles = model.profiles
        notice = model.notice
        if !profiles.contains(profile) {
            profile = profiles.first ?? ""
        }
        if let current = selected, !rows.contains(current) {
            selected = nil
        }
        onChange?()
    }

    private static func row(from target: Target) -> TargetRow {
        TargetRow(
            name: target.name,
            kind: kind(target.kind),
            detail: target.build.joined(separator: " ")
        )
    }

    private static func kind(_ kind: TargetKind) -> TargetRowKind {
        switch kind {
        case .bin: .bin
        case .lib: .lib
        case .test: .test
        case .bench: .bench
        case .example: .example
        case .custom: .custom
        }
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
