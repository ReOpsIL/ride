import Foundation

final class VisionIndex {
    struct Key: Equatable {
        let document: ObjectIdentifier
        let text: Int
        let length: Int
        let inputs: Int
    }

    private var key: Key?
    private(set) var lines: [VisionLine] = []
    private var byLine: [Int: VisionLine] = [:]

    func resolve(_ key: Key, build: () -> [VisionLine]) {
        guard key != self.key else {
            return
        }
        self.key = key
        lines = build()
        byLine = Dictionary(lines.map { ($0.line, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func line(_ number: Int) -> VisionLine? {
        byLine[number]
    }
}
