import XCTest

final class ShortcutsManualTests: XCTestCase {
    func testCommittedManualMatchesEntries() throws {
        let rendered = Self.markdown(Shortcuts.groups)
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

    static func markdown(_ groups: [ShortcutGroup]) -> String {
        var lines = [
            "# Keyboard shortcuts",
            "",
            "Editor commands take their keys only while the editor has keyboard focus. In the terminal, text fields and the project tree the same keys reach that control.",
        ]
        for group in groups {
            lines += ["", "## \(group.id)", "", "| Command | Keys | Scope | Notes |", "|---|---|---|---|"]
            for entry in group.entries {
                let scope = entry.bindings.allSatisfy { $0.scope == .editor } ? "editor" : "app"
                lines.append("| \(entry.name) | \(entry.keys) | \(scope) | \(entry.note ?? "") |")
            }
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
