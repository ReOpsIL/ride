import Foundation
import UniformTypeIdentifiers

enum HtmlPayload: Equatable {
    case deny
    case bytes(Data, mime: String, encoding: String?)
}

enum HtmlAsset {
    static let maxBytes = 8 * 1024 * 1024

    static func lexical(_ path: String) -> String? {
        var parts: [String] = []
        for part in path.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." {
                continue
            }
            if part == ".." {
                guard !parts.isEmpty else {
                    return nil
                }
                parts.removeLast()
                continue
            }
            if part.contains("\0") {
                return nil
            }
            parts.append(String(part))
        }
        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: "/")
    }

    static func file(root: URL, relative: String) -> URL? {
        guard let clean = lexical(relative) else {
            return nil
        }
        return contained(root: root, relative: clean)
    }

    static func payload(root: URL, name: String, page: String, url: URL?) -> HtmlPayload {
        guard let url, url.scheme == HtmlPage.scheme, url.host == HtmlPage.host, let relative = lexical(url.path) else {
            return .deny
        }
        if relative == name {
            let data = Data(HtmlPolicy.stamp(page).utf8)
            return .bytes(data, mime: "text/html", encoding: "utf-8")
        }
        return bytes(at: file(root: root, relative: relative))
    }

    private static func contained(root: URL, relative: String) -> URL? {
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let target = append(base, relative).standardizedFileURL.resolvingSymlinksInPath()
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard target.path == base.path || target.path.hasPrefix(prefix) else {
            return nil
        }
        return target
    }

    private static func append(_ root: URL, _ relative: String) -> URL {
        relative.split(separator: "/").reduce(root) { url, part in
            url.appendingPathComponent(String(part))
        }
    }

    private static func bytes(at url: URL?) -> HtmlPayload {
        guard let url, let data = read(url) else {
            return .deny
        }
        if HtmlPage.matches(url), let text = String(data: data, encoding: .utf8) {
            return .bytes(Data(HtmlPolicy.stamp(text).utf8), mime: "text/html", encoding: "utf-8")
        }
        return .bytes(data, mime: mime(url), encoding: nil)
    }

    private static func read(_ url: URL) -> Data? {
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), !directory.boolValue else {
            return nil
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= maxBytes else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func mime(_ url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
