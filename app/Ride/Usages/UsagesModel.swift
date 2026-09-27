import Foundation

final class UsagesModel: ObservableObject {
    static let shared = UsagesModel()

    @Published private(set) var name = ""
    @Published private(set) var primary: [UsageFileGroup] = []
    @Published private(set) var other: [UsageFileGroup] = []
    @Published private(set) var running = false
    @Published private(set) var finished = false

    private var generation = 0

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

    func query(document: BufferDocument, byte: UInt32) {
        generation += 1
        let current = generation
        running = true
        finished = false
        let started = SessionService.shared.read(document, lane: .workspace, { engine, id in
            _ = try? engine.noteSaved(sessionId: id)
            let response = engine.findUsages(sessionId: id, cursorByte: byte)
            return (response.name, UsageGrouping.split(response.hits.map(UsagesModel.row)))
        }, then: { [weak self] name, split in
            guard let self, self.generation == current else {
                return
            }
            self.name = name
            self.primary = split.primary
            self.other = split.other
            self.running = false
            self.finished = true
        })
        if !started {
            running = false
            finished = true
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
