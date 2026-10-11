import Foundation

enum MapIO {
    static func read(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url), data.count <= 1_000_000 else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func isFile(_ url: URL) -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &dir) && !dir.boolValue
    }

    static func isDirectory(_ url: URL) -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &dir) && dir.boolValue
    }

    static func children(_ url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    static func skip(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") || skipped.contains(name) { return true }
        return skippedSuffix.contains { name.hasSuffix($0) }
    }

    static func isSource(_ url: URL) -> Bool {
        sourceExt.contains(url.pathExtension.lowercased())
    }

    static func containsSource(_ url: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return false }
        for case let item as URL in enumerator {
            if skip(item) {
                enumerator.skipDescendants()
                continue
            }
            if isSource(item) { return true }
        }
        return false
    }

    private static let skipped: Set<String> = [
        "target", "build", "node_modules", "dist", "DerivedData", "Pods", "vendor", "Carthage",
    ]

    private static let skippedSuffix = [".xcodeproj", ".xcframework", ".dSYM", ".xcassets"]

    private static let sourceExt: Set<String> = [
        "rs", "swift", "c", "h", "hh", "hpp", "hxx", "cpp", "cc", "cxx", "m", "mm",
    ]
}
