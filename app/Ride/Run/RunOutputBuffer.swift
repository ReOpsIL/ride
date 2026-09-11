import Foundation

struct RunOutputBuffer {
    let maxLines: Int
    let dropChunk: Int
    private(set) var lines: [String] = []
    private(set) var first = 0

    init(maxLines: Int = 5000, dropChunk: Int = 500) {
        self.maxLines = max(1, maxLines)
        self.dropChunk = max(1, dropChunk)
    }

    var end: Int {
        first + lines.count
    }

    var last: String? {
        lines.last
    }

    mutating func append(_ line: String) {
        lines.append(line)
        guard lines.count > maxLines + dropChunk else {
            return
        }
        lines.removeFirst(dropChunk)
        first += dropChunk
    }

    mutating func clear() {
        lines = []
        first = 0
    }
}
