import Foundation

struct Pane: Identifiable, Equatable {
    let id: UUID
    var tabs: [UUID]
    var activeID: UUID?

    init(id: UUID = UUID(), tabs: [UUID] = [], activeID: UUID? = nil) {
        self.id = id
        self.tabs = tabs
        self.activeID = activeID
    }
}

struct PaneLayout: Equatable {
    private(set) var panes: [Pane]
    private(set) var focusedID: UUID

    init() {
        let pane = Pane()
        panes = [pane]
        focusedID = pane.id
    }

    var focused: Pane {
        panes.first { $0.id == focusedID } ?? panes[0]
    }

    var activeID: UUID? {
        get { focused.activeID }
        set {
            if let newValue {
                open(newValue, in: focusedID)
            } else {
                update(focusedID) { $0.activeID = nil }
            }
        }
    }

    func pane(_ id: UUID) -> Pane? {
        panes.first { $0.id == id }
    }

    func pane(showing bufferID: UUID) -> Pane? {
        panes.first { $0.activeID == bufferID } ?? panes.first { $0.tabs.contains(bufferID) }
    }

    func neighbour(of paneID: UUID) -> Pane? {
        guard let index = panes.firstIndex(where: { $0.id == paneID }) else {
            return nil
        }
        return index + 1 < panes.count ? panes[index + 1] : (index > 0 ? panes[index - 1] : nil)
    }

    mutating func focus(_ paneID: UUID) {
        if panes.contains(where: { $0.id == paneID }) {
            focusedID = paneID
        }
    }

    mutating func open(_ bufferID: UUID, in paneID: UUID) {
        update(paneID) { pane in
            if !pane.tabs.contains(bufferID) {
                pane.tabs.append(bufferID)
            }
            pane.activeID = bufferID
        }
    }

    mutating func select(_ bufferID: UUID) {
        guard let pane = pane(showing: bufferID) else {
            open(bufferID, in: focusedID)
            return
        }
        focusedID = pane.id
        update(pane.id) { $0.activeID = bufferID }
    }

    mutating func close(_ bufferID: UUID) {
        for pane in panes {
            update(pane.id) { pane in
                pane.tabs.removeAll { $0 == bufferID }
                if pane.activeID == bufferID {
                    pane.activeID = pane.tabs.last
                }
            }
        }
    }

    mutating func retain(_ bufferIDs: Set<UUID>) {
        for pane in panes {
            for tab in pane.tabs where !bufferIDs.contains(tab) {
                close(tab)
            }
        }
    }

    mutating func reset(tabs: [UUID], active: UUID?) {
        var pane = Pane()
        pane.tabs = tabs
        pane.activeID = active ?? tabs.last
        panes = [pane]
        focusedID = pane.id
    }

    mutating func move(_ bufferID: UUID, to paneID: UUID) {
        guard pane(paneID) != nil else {
            return
        }
        for pane in panes where pane.id != paneID {
            update(pane.id) { current in
                current.tabs.removeAll { $0 == bufferID }
                if current.activeID == bufferID {
                    current.activeID = current.tabs.last
                }
            }
        }
        open(bufferID, in: paneID)
        focusedID = paneID
    }

    @discardableResult
    mutating func split() -> UUID {
        if panes.count >= 2 {
            let other = neighbour(of: focusedID) ?? panes[1]
            focusedID = other.id
            return other.id
        }
        let pane = Pane()
        let index = panes.firstIndex { $0.id == focusedID } ?? panes.count - 1
        panes.insert(pane, at: index + 1)
        focusedID = pane.id
        return pane.id
    }

    mutating func closePane(_ paneID: UUID) {
        guard panes.count > 1, let closing = pane(paneID), let target = neighbour(of: paneID) else {
            return
        }
        panes.removeAll { $0.id == paneID }
        update(target.id) { pane in
            for tab in closing.tabs where !pane.tabs.contains(tab) {
                pane.tabs.append(tab)
            }
            if pane.activeID == nil {
                pane.activeID = closing.activeID ?? pane.tabs.last
            }
        }
        if focusedID == paneID {
            focusedID = target.id
        }
    }

    private mutating func update(_ paneID: UUID, _ change: (inout Pane) -> Void) {
        guard let index = panes.firstIndex(where: { $0.id == paneID }) else {
            return
        }
        change(&panes[index])
    }
}
