import Foundation

struct DebugFilterToggle: Identifiable, Equatable {
    let id: String
    let label: String
    var enabled: Bool
}

final class DebugFilters: ObservableObject {
    static let shared = DebugFilters()

    @Published private(set) var toggles: [DebugFilterToggle] = []
    private var loaded = false

    var enabledIds: [String] {
        toggles.filter(\.enabled).map(\.id)
    }

    var onChange: (() -> Void)?

    func load() {
        guard !loaded, let engine = RideEngineClient.shared.engine else {
            return
        }
        loaded = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = engine.debugExceptionFilters()
            DispatchQueue.main.async {
                self?.toggles = found.map { filter in
                    DebugFilterToggle(id: filter.id, label: filter.label, enabled: filter.defaultOn)
                }
                self?.onChange?()
            }
        }
    }

    func set(id: String, enabled: Bool) {
        guard let index = toggles.firstIndex(where: { $0.id == id }) else {
            return
        }
        toggles[index].enabled = enabled
        onChange?()
    }

    func toggle(id: String) {
        guard let found = toggles.first(where: { $0.id == id }) else {
            return
        }
        set(id: id, enabled: !found.enabled)
    }
}
