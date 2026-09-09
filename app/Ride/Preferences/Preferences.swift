import Foundation

struct Preferences: Codable, Equatable {
    var theme: String
    var fontSize: Int
    var tabWidth: Int
    var autoSave: Bool
    var completions: Bool
    var outlinePanel: Bool
    var visibleWhitespace: Bool
    var showHidden: Bool
    var checkOnSave: Bool
    var formatOnSave: Bool
    var sidebarWidth: Double
    var outlineWidth: Double
    var problemsHeight: Double

    static let defaults = Preferences(
        theme: "dark",
        fontSize: 13,
        tabWidth: 4,
        autoSave: true,
        completions: true,
        outlinePanel: true,
        visibleWhitespace: false,
        showHidden: false,
        checkOnSave: true,
        formatOnSave: false,
        sidebarWidth: 230,
        outlineWidth: 220,
        problemsHeight: 180
    )

    init(
        theme: String,
        fontSize: Int,
        tabWidth: Int,
        autoSave: Bool,
        completions: Bool,
        outlinePanel: Bool,
        visibleWhitespace: Bool,
        showHidden: Bool,
        checkOnSave: Bool = true,
        formatOnSave: Bool = false,
        sidebarWidth: Double = 230,
        outlineWidth: Double = 220,
        problemsHeight: Double = 180
    ) {
        self.theme = theme
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.autoSave = autoSave
        self.completions = completions
        self.outlinePanel = outlinePanel
        self.visibleWhitespace = visibleWhitespace
        self.showHidden = showHidden
        self.checkOnSave = checkOnSave
        self.formatOnSave = formatOnSave
        self.sidebarWidth = sidebarWidth
        self.outlineWidth = outlineWidth
        self.problemsHeight = problemsHeight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences.defaults
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? d.theme
        fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize) ?? d.fontSize
        tabWidth = try c.decodeIfPresent(Int.self, forKey: .tabWidth) ?? d.tabWidth
        autoSave = try c.decodeIfPresent(Bool.self, forKey: .autoSave) ?? d.autoSave
        completions = try c.decodeIfPresent(Bool.self, forKey: .completions) ?? d.completions
        outlinePanel = try c.decodeIfPresent(Bool.self, forKey: .outlinePanel) ?? d.outlinePanel
        visibleWhitespace = try c.decodeIfPresent(Bool.self, forKey: .visibleWhitespace) ?? d.visibleWhitespace
        showHidden = try c.decodeIfPresent(Bool.self, forKey: .showHidden) ?? d.showHidden
        checkOnSave = try c.decodeIfPresent(Bool.self, forKey: .checkOnSave) ?? d.checkOnSave
        formatOnSave = try c.decodeIfPresent(Bool.self, forKey: .formatOnSave) ?? d.formatOnSave
        sidebarWidth = try c.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? d.sidebarWidth
        outlineWidth = try c.decodeIfPresent(Double.self, forKey: .outlineWidth) ?? d.outlineWidth
        problemsHeight = try c.decodeIfPresent(Double.self, forKey: .problemsHeight) ?? d.problemsHeight
    }

    var clamped: Preferences {
        var next = self
        next.fontSize = min(18, max(11, fontSize))
        next.tabWidth = min(8, max(2, tabWidth))
        next.sidebarWidth = min(420, max(180, sidebarWidth))
        next.outlineWidth = min(420, max(160, outlineWidth))
        next.problemsHeight = min(480, max(80, problemsHeight))
        if next.theme != "light" {
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
