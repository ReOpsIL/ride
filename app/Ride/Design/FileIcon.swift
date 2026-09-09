import AppKit

struct FileIconSpec {
    let symbol: String
    let color: NSColor
}

enum FileIcon {
    static func spec(name: String, isDirectory: Bool, expanded: Bool = false, chrome: ChromeColors) -> FileIconSpec {
        if isDirectory {
            return FileIconSpec(symbol: expanded ? "folder.fill" : "folder", color: chrome.textSecondary)
        }
        let lower = name.lowercased()
        if lower == "cargo.toml" {
            return FileIconSpec(symbol: "shippingbox.fill", color: chrome.accent)
        }
        if lower == "cargo.lock" || lower.hasSuffix(".lock") {
            return FileIconSpec(symbol: "lock.fill", color: chrome.textTertiary)
        }
        switch (lower as NSString).pathExtension {
        case "rs": return FileIconSpec(symbol: "doc.text.fill", color: chrome.warning)
        case "toml", "yml", "yaml": return FileIconSpec(symbol: "slider.horizontal.3", color: chrome.accent)
        case "md", "txt": return FileIconSpec(symbol: "doc.richtext", color: chrome.info)
        case "json": return FileIconSpec(symbol: "curlybraces", color: chrome.success)
        case "sh": return FileIconSpec(symbol: "terminal", color: chrome.success)
        case "png", "jpg", "jpeg", "svg", "icns": return FileIconSpec(symbol: "photo", color: chrome.info)
        default: return FileIconSpec(symbol: "doc", color: chrome.textSecondary)
        }
    }
}
