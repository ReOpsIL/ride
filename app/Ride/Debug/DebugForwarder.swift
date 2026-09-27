import Foundation

final class DebugForwarder: DebugListener, @unchecked Sendable {
    weak var controller: DebugController?

    init(controller: DebugController) {
        self.controller = controller
    }

    func onEvent(event: DebugEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let controller = self.controller, controller.accepts(self) else {
                return
            }
            controller.handle(event)
        }
    }

    func onOutput(category: String, text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let controller = self.controller, controller.accepts(self) else {
                return
            }
            controller.onOutput?(category, text)
        }
    }
}
