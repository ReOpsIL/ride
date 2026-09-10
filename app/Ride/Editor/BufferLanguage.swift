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
}
