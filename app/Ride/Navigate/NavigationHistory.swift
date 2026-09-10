import Foundation

struct NavLocation: Equatable {
    let bufferID: UUID
    let utf16: Int
}

final class NavigationHistory {
    static let capacity = 100
    private(set) var entries: [NavLocation] = []
    private(set) var index = -1
    private(set) var lastEdit: NavLocation?

    var canGoBack: Bool {
        index > 0
    }

    var canGoForward: Bool {
        index >= 0 && index < entries.count - 1
    }

    func record(_ location: NavLocation, lines: (Int) -> Int) {
        if index >= 0, index < entries.count {
            let current = entries[index]
            if current.bufferID == location.bufferID, lines(current.utf16) == lines(location.utf16) {
                entries[index] = location
                return
            }
        }
        entries.removeSubrange((index + 1)...)
        entries.append(location)
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
        index = entries.count - 1
    }

    func back(from current: NavLocation, lines: (Int) -> Int) -> NavLocation? {
        record(current, lines: lines)
        guard canGoBack else {
            return nil
        }
        index -= 1
        return entries[index]
    }

    func forward() -> NavLocation? {
        guard canGoForward else {
            return nil
        }
        index += 1
        return entries[index]
    }

    func noteEdit(_ location: NavLocation) {
        lastEdit = location
    }

    func forget(bufferID: UUID) {
        entries.removeAll { $0.bufferID == bufferID }
        index = min(index, entries.count - 1)
        if lastEdit?.bufferID == bufferID {
            lastEdit = nil
        }
    }
}
