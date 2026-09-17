import Foundation

final class UsagesModel: ObservableObject {
    static let shared = UsagesModel()

    @Published private(set) var name = ""
    @Published private(set) var primary: [UsageFileGroup] = []
    @Published private(set) var other: [UsageFileGroup] = []
    @Published private(set) var running = false
    @Published private(set) var finished = false

    private var generation = 0
    private static let queue = DispatchQueue(label: "ride.usages.query", qos: .userInitiated)

    var total: Int {
        UsageGrouping.total(primary) + UsageGrouping.total(other)
    }

    func clear() {
        generation += 1
        name = ""
        primary = []
        other = []
        running = false
        finished = false
    }

    func query(sessionId: UInt64, byte: UInt32) {
        generation += 1
        let current = generation
        running = true
        finished = false
        guard let engine = RideEngineClient.shared.engine else {
            running = false
            finished = true
            return
        }
        UsagesModel.queue.async {
            _ = try? engine.noteSaved(sessionId: sessionId)
            let response = engine.findUsages(sessionId: sessionId, cursorByte: byte)
            let rows = response.hits.map(UsagesModel.row)
            let split = UsageGrouping.split(rows)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == current else {
                    return
                }
                self.name = response.name
                self.primary = split.primary
                self.other = split.other
                self.running = false
                self.finished = true
            }
        }
    }

    private static func row(_ hit: UsageHit) -> UsageRow {
        UsageRow(
            path: hit.path,
            line: hit.line,
            byteStart: hit.byteStart,
            byteEnd: hit.byteEnd,
            enclosingItem: hit.enclosingItem,
            enclosingKind: SessionService.kindLabel(hit.enclosingKind),
            inDefinitionScope: hit.inDefinitionScope
        )
    }
}
