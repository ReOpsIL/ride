import Foundation

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
        guard !DemoLaunch.isDemo else {
            return
        }
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
