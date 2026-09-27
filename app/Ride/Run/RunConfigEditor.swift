import Combine
import Foundation

final class RunConfigEditor: ObservableObject {
    @Published var draft = RunConfigDraft()
    @Published private(set) var target = ""
    @Published private(set) var kind = RunProjectKind.none

    var sanitizers: [Sanitizer] {
        Sanitizer.supported(by: kind)
    }

    var requiresNightly: Bool {
        draft.requiresNightly(kind: kind)
    }

    var config: RunConfig {
        draft.config(target: target)
    }

    func begin(_ config: RunConfig, kind: RunProjectKind) {
        target = config.target
        self.kind = kind
        draft = RunConfigDraft(config)
    }

    func addEnvRow() {
        draft.env.append(RunConfigEnvRow())
    }

    func removeEnvRow(id: UUID) {
        draft.env.removeAll { $0.id == id }
    }

    func isOn(_ sanitizer: Sanitizer) -> Bool {
        draft.sanitizers.contains(sanitizer)
    }

    func set(_ sanitizer: Sanitizer, on: Bool) {
        draft.set(sanitizer, on: on)
    }
}
