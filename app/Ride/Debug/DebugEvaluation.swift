import Combine
import Foundation

final class DebugEvaluation: ObservableObject {
    static let shared = DebugEvaluation()

    @Published var expression = ""
    @Published private(set) var result = ""
    @Published private(set) var failed = false

    var trimmed: String {
        expression.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !trimmed.isEmpty
    }

    func evaluate(in model: DebugPanelModel) {
        let text = trimmed
        guard !text.isEmpty else {
            return
        }
        result = "evaluating…"
        failed = false
        model.evaluate(text, context: .repl) { [weak self] row in
            guard let row else {
                self?.show("not stopped", failed: true)
                return
            }
            self?.show(row.typeName.map { "\(row.value)  ·  \($0)" } ?? row.value, failed: row.failed)
        }
    }

    func watch(in model: DebugPanelModel) {
        model.addWatch(trimmed)
    }

    func close(_ model: DebugPanelModel) {
        model.showEvaluate = false
    }

    private func show(_ text: String, failed: Bool) {
        result = text
        self.failed = failed
    }
}
