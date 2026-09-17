import Foundation

func cargoEdition(_ root: URL) -> String? {
    let url = root.appendingPathComponent("Cargo.toml")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        return nil
    }
    return CargoManifest.field("edition", in: text)
}

enum CargoManifest {
    static func field(_ key: String, in text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(key),
                  trimmed.dropFirst(key.count).trimmingCharacters(in: .whitespaces).hasPrefix("=")
            else {
                continue
            }
            guard let first = trimmed.firstIndex(of: "\""),
                  let last = trimmed.lastIndex(of: "\""),
                  first < last
            else {
                continue
            }
            return String(trimmed[trimmed.index(after: first) ..< last])
        }
        return nil
    }
}
