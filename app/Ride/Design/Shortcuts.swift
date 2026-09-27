enum ShortcutScope {
    case app
    case editor
}

struct ShortcutBinding {
    static let separator = " › "

    let path: String?
    let keys: String
    let scope: ShortcutScope

    var combo: KeyCombo? {
        KeyCombo(glyphs: keys)
    }

    static func menu(_ path: String, _ keys: String, _ scope: ShortcutScope = .app) -> ShortcutBinding {
        ShortcutBinding(path: path, keys: keys, scope: scope)
    }

    static func editorKey(_ keys: String) -> ShortcutBinding {
        ShortcutBinding(path: nil, keys: keys, scope: .editor)
    }
}

struct ShortcutEntry: Identifiable {
    let id: String
    let name: String
    let bindings: [ShortcutBinding]
    var note: String?

    init(_ id: String, _ name: String, _ bindings: [ShortcutBinding], note: String? = nil) {
        self.id = id
        self.name = name
        self.bindings = bindings
        self.note = note
    }

    var keys: String {
        bindings.map(\.keys).joined(separator: " · ")
    }
}

struct ShortcutGroup: Identifiable {
    let id: String
    let entries: [ShortcutEntry]
}

enum Shortcuts {
    static let groups: [ShortcutGroup] = fileEditView + navigateCode + runDebug

    static var entries: [ShortcutEntry] {
        groups.flatMap(\.entries)
    }

    static var bindings: [ShortcutBinding] {
        entries.flatMap(\.bindings)
    }

    static let editorScoped: Set<KeyCombo> = Set(
        groups.flatMap(\.entries).flatMap(\.bindings).filter { $0.scope == .editor && $0.path != nil }.compactMap(\.combo)
    )

    static func keys(for path: String) -> String? {
        bindings.first { $0.path == path }?.keys
    }

    static func help(_ label: String, _ path: String) -> String {
        keys(for: path).map { "\(label) (\($0))" } ?? label
    }
}
