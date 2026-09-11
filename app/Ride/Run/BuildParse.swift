import Foundation

enum BuildParse {
    static let cargoFormat = "--message-format=json-diagnostic-rendered-ansi"

    static func cargoArgv(_ argv: [String]) -> [String] {
        guard argv.first == "cargo",
              !argv.contains(where: { $0.hasPrefix("--message-format") })
        else {
            return argv
        }
        guard let separator = argv.firstIndex(of: "--") else {
            return argv + [cargoFormat]
        }
        var out = argv
        out.insert(cargoFormat, at: separator)
        return out
    }

    static func isMessage(_ line: String) -> Bool {
        line.hasPrefix("{")
    }

    static func rendered(_ line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["message"] as? [String: Any],
              let text = message["rendered"] as? String
        else {
            return nil
        }
        let trimmed = text.hasSuffix("\n") ? String(text.dropLast()) : text
        return trimmed.isEmpty ? nil : trimmed
    }

    static func panelLine(_ line: String) -> String? {
        isMessage(line) ? rendered(line) : line
    }
}
