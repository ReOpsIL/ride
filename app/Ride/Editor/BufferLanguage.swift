import Foundation

enum BufferLanguage {
    case rust
    case c
    case cpp
    case markdown
    case plain

    static let cExtensions: Set<String> = ["c", "h"]
    static let cppExtensions: Set<String> = [
        "cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "inl", "ipp", "tpp", "cppm", "ixx",
    ]

    static func of(_ url: URL?) -> BufferLanguage {
        guard let url else {
            return .rust
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "rs": return .rust
        case "md", "markdown": return .markdown
        case _ where cExtensions.contains(ext): return .c
        case _ where cppExtensions.contains(ext): return .cpp
        default: return .plain
        }
    }

    var hasCompletions: Bool {
        switch self {
        case .rust, .c, .cpp: return true
        case .markdown, .plain: return false
        }
    }

    var title: String? {
        switch self {
        case .rust: return "Rust"
        case .c: return "C"
        case .cpp: return "C++"
        case .markdown, .plain: return nil
        }
    }

    var fileExtension: String {
        switch self {
        case .rust: return "rs"
        case .c: return "c"
        case .cpp: return "cpp"
        case .markdown: return "md"
        case .plain: return "txt"
        }
    }

    var usesClang: Bool {
        self == .c || self == .cpp
    }
}
