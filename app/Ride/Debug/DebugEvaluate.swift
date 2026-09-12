import Foundation

extension DebugPanelModel {
    static func evaluateAll(
        _ expressions: [String],
        engine: Engine,
        session: UInt64,
        frame: Int64
    ) -> [WatchRow] {
        let box = WatchBox(count: expressions.count)
        DispatchQueue.concurrentPerform(iterations: expressions.count) { index in
            let row = evaluate(
                expressions[index],
                engine: engine,
                session: session,
                frame: frame,
                context: .watch
            )
            box.set(index, row)
        }
        return box.rows()
    }

    static func evaluate(
        _ expression: String,
        engine: Engine,
        session: UInt64,
        frame: Int64,
        context: DebugEvaluateContext
    ) -> WatchRow {
        do {
            let value = try engine.debugEvaluate(
                sessionId: session,
                frameId: frame,
                expression: expression,
                context: context
            )
            return WatchRow(id: expression, value: value.value, typeName: value.typeName, failed: false)
        } catch {
            return WatchRow(id: expression, value: "\(error)", typeName: nil, failed: true)
        }
    }
}

final class WatchBox: @unchecked Sendable {
    private let lock = NSLock()
    private var slots: [WatchRow?]

    init(count: Int) {
        slots = Array(repeating: nil, count: count)
    }

    func set(_ index: Int, _ row: WatchRow) {
        lock.lock()
        slots[index] = row
        lock.unlock()
    }

    func rows() -> [WatchRow] {
        lock.lock()
        defer { lock.unlock() }
        return slots.compactMap { $0 }
    }
}
