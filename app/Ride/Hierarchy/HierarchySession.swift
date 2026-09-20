import Foundation

struct HierarchySession {
    let id: UInt64
    let owned: Bool
    let names: [String]
    let start: [UInt32]
    let end: [UInt32]
    let nameStart: [UInt32]

    init(id: UInt64, owned: Bool, rows: [OutlineRow]) {
        self.id = id
        self.owned = owned
        names = rows.map(\.name)
        start = rows.map(\.startByte)
        end = rows.map(\.endByte)
        nameStart = rows.map(\.startByte)
    }

    init(id: UInt64, owned: Bool, items: [OutlineItem]) {
        self.id = id
        self.owned = owned
        names = items.map(\.name)
        start = items.map(\.startByte)
        end = items.map(\.endByte)
        nameStart = items.map(\.nameStartByte)
    }

    func close(_ engine: Engine) {
        if owned {
            engine.closeSession(sessionId: id)
        }
    }

    func expandByte(name: String, byte: UInt32) -> UInt32 {
        var best: (size: UInt32, at: UInt32)?
        for index in start.indices where start[index] <= byte && byte < end[index] {
            if !name.isEmpty && names[index] != name {
                continue
            }
            let size = end[index] - start[index]
            if best.map({ size < $0.size }) ?? true {
                best = (size, nameStart[index])
            }
        }
        return best?.at ?? byte
    }
}
