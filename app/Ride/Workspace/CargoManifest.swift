import Foundation

func cargoPackageName(_ root: URL) -> String? {
    cargoField("name", root: root)
}

func cargoEdition(_ root: URL) -> String? {
    cargoField("edition", root: root)
}

private func cargoField(_ key: String, root: URL) -> String? {
    let url = root.appendingPathComponent("Cargo.toml")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        return nil
    }
    return CargoManifest.field(key, in: text)
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
