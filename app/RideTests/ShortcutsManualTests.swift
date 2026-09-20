import XCTest

final class ShortcutsManualTests: XCTestCase {
    func testCommittedManualMatchesEntries() throws {
        let rendered = Self.markdown(Shortcuts.entries)
        let url = Self.manualURL()
        if ProcessInfo.processInfo.environment["RIDE_WRITE_MANUALS"] != nil {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try rendered.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        let committed = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(committed, rendered)
    }

    static func markdown(_ entries: [ShortcutEntry]) -> String {
        var lines = ["# Keyboard shortcuts", "", "| Command | Keys |", "|---|---|"]
        for entry in entries {
            lines.append("| \(entry.name) | \(entry.keys) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func manualURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/manuals/shortcuts.md")
    }
}
