import Foundation

enum DocPage {
    static func html(title: String, signature: String, body: String) -> String {
        var parts: [String] = []
        if !title.isEmpty {
            parts.append("<h1>\(escape(title))</h1>")
        }
        if !signature.isEmpty {
            parts.append("<pre><code>\(escape(signature))</code></pre>")
        }
        parts.append(body)
        return parts.joined()
    }

    static func origin(path: String, line: UInt32) -> String {
        guard !path.isEmpty else {
            return ""
        }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return line > 0 ? "\(name):\(line)" : name
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

enum DocLinkTarget {
    static let prefix = "ride-doc://"

    static func item(url: String) -> String? {
        guard url.hasPrefix(prefix) else {
            return nil
        }
        return String(url.dropFirst(prefix.count))
    }
}

enum DocExternal {
    static func url(name: String, crate: String, path: String) -> URL? {
        if !crate.isEmpty {
            return docsRs(crate: crate, name: name)
        }
        if path.contains("std::") || name.contains("std::") {
            return cppreference(name: searchName(name, path: path))
        }
        return nil
    }

    static func docsRs(crate: String, name: String) -> URL? {
        let c = encodePath(crate)
        let q = encodeQuery(name)
        return URL(string: "https://docs.rs/\(c)/latest/\(c)/?search=\(q)")
    }

    static func cppreference(name: String) -> URL? {
        URL(string: "https://en.cppreference.com/w/?search=\(encodeQuery(name))")
    }

    static func searchName(_ name: String, path: String) -> String {
        if path.contains("std::") {
            return path
        }
        return name
    }

    static func encodePath(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? text
    }

    static func encodeQuery(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "?&")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}
