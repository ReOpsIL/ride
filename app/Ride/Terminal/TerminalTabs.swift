import Foundation

struct TerminalTabItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var directory: String?

    init(id: UUID = UUID(), title: String, directory: String? = nil) {
        self.id = id
        self.title = title
        self.directory = directory
    }
}

struct TerminalTabs: Equatable {
    private(set) var items: [TerminalTabItem] = []
    private(set) var selected: UUID?

    var count: Int {
        items.count
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    var selectedItem: TerminalTabItem? {
        guard let selected else {
            return nil
        }
        return items.first { $0.id == selected }
    }

    func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    mutating func add(_ item: TerminalTabItem) {
        items.append(item)
        selected = item.id
    }

    mutating func select(_ id: UUID) {
        guard index(of: id) != nil else {
            return
        }
        selected = id
    }

    mutating func rename(_ id: UUID, title: String) {
        guard let index = index(of: id), !title.isEmpty else {
            return
        }
        items[index].title = title
    }

    mutating func close(_ id: UUID) {
        guard let index = index(of: id) else {
            return
        }
        items.remove(at: index)
        guard selected == id else {
            return
        }
        selected = fallback(at: index)
    }

    mutating func removeAll() {
        items = []
        selected = nil
    }

    private func fallback(at index: Int) -> UUID? {
        if items.indices.contains(index) {
            return items[index].id
        }
        return items.last?.id
    }

    static func title(for directory: String?) -> String {
        guard let directory, !directory.isEmpty else {
            return "shell"
        }
        let name = URL(fileURLWithPath: directory).lastPathComponent
        return name.isEmpty || name == "/" ? "shell" : name
    }
}
