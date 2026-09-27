import Foundation

enum SessionLane {
    case session
    case workspace
}

enum SessionDelivery {
    case currentText
    case always
}

extension SessionService {
    @discardableResult
    func read<T>(
        _ document: BufferDocument,
        lane: SessionLane = .session,
        delivery: SessionDelivery = .always,
        qos: DispatchQoS.QoSClass = .userInitiated,
        _ work: @escaping (Engine, UInt64) -> T,
        then done: @escaping (T) -> Void
    ) -> Bool {
        guard let id = document.sessionId, let engine = RideEngineClient.shared.engine else {
            return false
        }
        let mark = document.textGeneration
        let deliver: (T) -> Void = { value in
            DispatchQueue.main.async {
                guard document.sessionId == id, delivery == .always || document.textGeneration == mark else {
                    return
                }
                done(value)
            }
        }
        queue(id).async {
            switch lane {
            case .session:
                deliver(work(engine, id))
            case .workspace:
                DispatchQueue.global(qos: qos).async {
                    deliver(work(engine, id))
                }
            }
        }
        return true
    }

    func readNow<T>(_ document: BufferDocument, _ work: (Engine, UInt64) -> T) -> T? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let id = document.sessionId, let engine = RideEngineClient.shared.engine else {
            return nil
        }
        return queue(id).sync {
            work(engine, id)
        }
    }

    func replaceText(of document: BufferDocument, with text: String) {
        guard let id = document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        queue(id).async {
            _ = try? engine.setText(sessionId: id, text: text, visible: nil)
        }
    }
}
