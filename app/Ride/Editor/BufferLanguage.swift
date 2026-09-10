import Foundation

enum BufferLanguage {
    case rust
    case c
    case cpp
    case toml
    case make
    case cmake
    case markdown
    case plain

    static let cExtensions: Set<String> = ["c", "h"]
    static let cppExtensions: Set<String> = [
        "cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "inl", "ipp", "tpp", "cppm", "ixx",
    ]

    static let makeNames: Set<String> = ["makefile", "gnumakefile"]
    static let makeExtensions: Set<String> = ["mk", "mak", "make"]

    static func of(_ url: URL?) -> BufferLanguage {
        guard let url else {
            return .rust
        }
        let name = url.lastPathComponent.lowercased()
        if makeNames.contains(name) {
            return .make
        }
        if name == "cmakelists.txt" {
            return .cmake
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "rs": return .rust
        case "md", "markdown": return .markdown
        case "toml": return .toml
        case "cmake": return .cmake
        case _ where cExtensions.contains(ext): return .c
        case _ where cppExtensions.contains(ext): return .cpp
        case _ where makeExtensions.contains(ext): return .make
        default: return .plain
        }
    }

    static func sniff(url: URL?, text: String, systemDirs: [URL] = []) -> BufferLanguage {
        if let url, isExtensionless(url), isCpp(url: url, text: text, systemDirs: systemDirs) {
            return .cpp
        }
        return of(url)
    }

    static func isReadOnly(_ url: URL, systemDirs: [URL] = []) -> Bool {
        isSystemInclude(url, systemDirs: systemDirs)
    }

    static func isSystemInclude(_ url: URL, systemDirs: [URL] = []) -> Bool {
        let path = url.standardizedFileURL.path
        if systemDirs.contains(where: { under(path, dir: $0) }) {
            return true
        }
        return path.hasPrefix("/usr/include")
            || path.hasPrefix("/usr/local/include")
            || path.contains("/usr/include/")
            || path.contains("/include/c++/")
            || path.contains("/c++/v1/")
            || path.hasSuffix("/c++/v1")
    }

    var hasCompletions: Bool {
        switch self {
        case .rust, .c, .cpp, .toml, .make, .cmake: return true
        case .markdown, .plain: return false
        }
    }

    var title: String? {
        switch self {
        case .rust: return "Rust"
        case .c: return "C"
        case .cpp: return "C++"
        case .toml: return "TOML"
        case .make: return "Makefile"
        case .cmake: return "CMake"
        case .markdown, .plain: return nil
        }
    }

    var fileExtension: String {
        switch self {
        case .rust: return "rs"
        case .c: return "c"
        case .cpp: return "cpp"
        case .toml: return "toml"
        case .make: return "mk"
        case .cmake: return "cmake"
        case .markdown: return "md"
        case .plain: return "txt"
        }
    }

    var usesClang: Bool {
        self == .c || self == .cpp
    }

    var hasSignatureHelp: Bool {
        self == .rust || usesClang
    }

    private static let cppLineStarts = [
        "namespace ", "class ", "template ", "template<", "using ",
        "public:", "private:", "protected:", "extern \"C++\"",
    ]

    private static func isExtensionless(_ url: URL) -> Bool {
        url.pathExtension.isEmpty
    }

    private static func isCpp(url: URL, text: String, systemDirs: [URL]) -> Bool {
        isSystemInclude(url, systemDirs: systemDirs) || isCppHeader(text)
    }

    private static func isCppHeader(_ text: String) -> Bool {
        var seen = 0
        for line in text.split(whereSeparator: \.isNewline) {
            seen += line.utf8.count + 1
            if seen > 64 * 1024 {
                break
            }
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if startsCpp(trimmed) || includesCppStd(trimmed) {
                return true
            }
        }
        return false
    }

    private static func startsCpp(_ line: Substring) -> Bool {
        cppLineStarts.contains { line.hasPrefix($0) }
    }

    private static func includesCppStd(_ line: Substring) -> Bool {
        guard line.first == "#" else {
            return false
        }
        var rest = line.dropFirst()
        rest = rest.drop { $0 == " " || $0 == "\t" }
        guard rest.hasPrefix("include") else {
            return false
        }
        rest = rest.dropFirst("include".count)
        rest = rest.drop { $0 == " " || $0 == "\t" }
        guard rest.first == "<", let close = rest.firstIndex(of: ">") else {
            return false
        }
        let name = rest[rest.index(after: rest.startIndex)..<close]
        return !name.isEmpty && !name.contains(".")
    }

    private static func under(_ path: String, dir: URL) -> Bool {
        let root = dir.standardizedFileURL.path
        if path == root {
            return true
        }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix)
    }
}
