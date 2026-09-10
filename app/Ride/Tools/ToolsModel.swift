import Foundation

struct ToolRow: Identifiable, Equatable {
    let info: ToolInfo
    var selected: Bool
    var result: String?

    var id: String { info.name }
    var missing: Bool { info.path == nil }
}

final class ToolsModel: ObservableObject {
    static let shared = ToolsModel()
    @Published var rows: [ToolRow] = []
    @Published var installing = false
    @Published var log = ""
    @Published var checked = false

    var missing: [ToolRow] {
        rows.filter(\.missing)
    }

    var installable: [ToolRow] {
        missing.filter { $0.info.install != nil }
    }

    func refresh(done: (() -> Void)? = nil) {
        guard let engine = RideEngineClient.shared.engine else {
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let tools = engine.toolStatus()
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                let previous = Dictionary(uniqueKeysWithValues: self.rows.map { ($0.id, $0) })
                self.rows = tools.map { info in
                    ToolRow(info: info, selected: previous[info.name]?.selected ?? (info.install != nil), result: previous[info.name]?.result)
                }
                self.checked = true
                done?()
            }
        }
    }

    func installSelected() {
        let commands = rows.filter { $0.missing && $0.selected && $0.info.install != nil }
            .map { ($0.id, $0.info.install ?? "") }
        guard !commands.isEmpty, !installing else {
            return
        }
        installing = true
        log = ""
        ToolInstaller.run(commands) { [weak self] name, output, success in
            guard let self else {
                return
            }
            self.log += "$ \(commands.first { $0.0 == name }?.1 ?? name)\n\(output)\n"
            if let index = self.rows.firstIndex(where: { $0.id == name }) {
                self.rows[index].result = success ? "installed" : "failed"
            }
        } done: { [weak self] in
            self?.installing = false
            self?.refresh()
        }
    }
}
