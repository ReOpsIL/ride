struct MenuShortcut: Hashable {
    let path: String
    let combo: KeyCombo
}

struct ShortcutAudit {
    let menu: [MenuShortcut]
    let bindings: [ShortcutBinding]
    let exempt: [String: String]

    var duplicates: [String] {
        Dictionary(grouping: menu, by: \.combo)
            .filter { Set($0.value.map(\.path)).count > 1 }
            .map { combo, items in "\(combo) on " + items.map(\.path).sorted().joined(separator: " and ") }
            .sorted()
    }

    var mismatched: [String] {
        let actual = Dictionary(grouping: menu, by: \.path).mapValues { Set($0.map(\.combo)) }
        return bindings.compactMap { binding -> String? in
            guard let path = binding.path else {
                return nil
            }
            guard let combos = actual[path] else {
                return "panel lists \(binding.keys) for \(path), which has no key equivalent"
            }
            guard let combo = binding.combo, combos.contains(combo) else {
                return "panel lists \(binding.keys) for \(path), menu has " + combos.map(\.description).sorted().joined(separator: " ")
            }
            return nil
        }.sorted()
    }

    var unlisted: [String] {
        let listed = Set(bindings.compactMap { binding in binding.combo.flatMap { combo in binding.path.map { MenuShortcut(path: $0, combo: combo) } } })
        return menu.filter { !listed.contains($0) && exempt[$0.path] == nil }.map { "\($0.combo) \($0.path) missing from the panel" }.sorted()
    }

    var problems: [String] {
        duplicates.map { "duplicate \($0)" } + mismatched + unlisted
    }

    var listing: String {
        let rows = menu.sorted { $0.path < $1.path }.map { item -> String in
            let reason = exempt[item.path].map { " (exempt: \($0))" } ?? ""
            return "\(item.combo.description.padding(toLength: 8, withPad: " ", startingAt: 0)) \(item.path)\(reason)"
        }
        return (rows + [""] + problems).joined(separator: "\n") + "\n"
    }
}

extension ShortcutAudit {
    static let systemItems: [String: String] = {
        let standard = "standard macOS item with its system-wide key"
        let paths = [
            "Ride › Settings…", "Ride › Hide Ride", "Ride › Hide Others", "Ride › Quit Ride",
            "Edit › Undo", "Edit › Redo", "Edit › Cut", "Edit › Copy", "Edit › Paste", "Edit › Select All",
            "Edit › Emoji & Symbols", "Window › Minimize",
        ]
        return Dictionary(uniqueKeysWithValues: paths.map { ($0, standard) })
    }()
}
