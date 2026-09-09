import Foundation

struct Preferences: Codable, Equatable {
    var theme: String
    var fontSize: Int
    var tabWidth: Int
    var autoSave: Bool
    var completions: Bool
    var outlinePanel: Bool
    var visibleWhitespace: Bool

    static let defaults = Preferences(
        theme: "dark",
        fontSize: 13,
        tabWidth: 4,
        autoSave: true,
        completions: true,
        outlinePanel: true,
        visibleWhitespace: false
    )

    var clamped: Preferences {
        var next = self
        next.fontSize = min(18, max(11, fontSize))
        next.tabWidth = min(8, max(2, tabWidth))
        if next.theme.isEmpty {
            next.theme = "dark"
        }
        return next
    }
}

enum PreferencesStore {
    static func load() -> Preferences {
        guard let data = try? Data(contentsOf: fileURL()),
              let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else {
            return .defaults
        }
        return decoded.clamped
    }

    static func save(_ prefs: Preferences) {
        let dir = fileURL().deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(prefs.clamped) {
            try? data.write(to: fileURL(), options: .atomic)
        }
    }

    static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Ride/preferences.json")
    }
}
