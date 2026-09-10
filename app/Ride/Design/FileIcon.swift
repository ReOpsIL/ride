import AppKit

struct FileIconSpec {
    let symbol: String
    let color: NSColor
}

enum FileIcon {
    static func spec(for buffer: BufferDocument, chrome: ChromeColors) -> FileIconSpec {
        switch buffer.language {
        case .c: return c(chrome)
        case .cpp: return cpp(chrome)
        case .make: return make(chrome)
        case .cmake: return cmake(chrome)
        default: return spec(name: buffer.displayName, isDirectory: false, chrome: chrome)
        }
    }

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
        if BufferLanguage.makeNames.contains(lower) {
            return make(chrome)
        }
        if lower == "cmakelists.txt" {
            return cmake(chrome)
        }
        let ext = (lower as NSString).pathExtension
        switch ext {
        case "rs": return FileIconSpec(symbol: "doc.text.fill", color: chrome.warning)
        case _ where BufferLanguage.cExtensions.contains(ext): return c(chrome)
        case _ where BufferLanguage.cppExtensions.contains(ext): return cpp(chrome)
        case _ where BufferLanguage.makeExtensions.contains(ext): return make(chrome)
        case "cmake": return cmake(chrome)
        case "toml", "yml", "yaml": return FileIconSpec(symbol: "slider.horizontal.3", color: chrome.accent)
        case "md", "txt": return FileIconSpec(symbol: "doc.richtext", color: chrome.info)
        case "json": return FileIconSpec(symbol: "curlybraces", color: chrome.success)
        case "sh": return FileIconSpec(symbol: "terminal", color: chrome.success)
        case "png", "jpg", "jpeg", "svg", "icns": return FileIconSpec(symbol: "photo", color: chrome.info)
        default: return FileIconSpec(symbol: "doc", color: chrome.textSecondary)
        }
    }

    private static func c(_ chrome: ChromeColors) -> FileIconSpec {
        FileIconSpec(symbol: "c.square.fill", color: chrome.info)
    }

    private static func cpp(_ chrome: ChromeColors) -> FileIconSpec {
        FileIconSpec(symbol: "c.square.fill", color: chrome.accent)
    }

    private static func make(_ chrome: ChromeColors) -> FileIconSpec {
        FileIconSpec(symbol: "hammer.fill", color: chrome.success)
    }

    private static func cmake(_ chrome: ChromeColors) -> FileIconSpec {
        FileIconSpec(symbol: "gearshape.2.fill", color: chrome.info)
    }
}
