import Foundation

enum NewFileKind {
    case cargo
    case cmake
    case make
    case other
}

enum NewFilePrompt {
    static let languages: [BufferLanguage] = [.rust, .c, .cpp, .toml, .make, .cmake, .markdown]

    static func language(for kind: NewFileKind) -> BufferLanguage {
        switch kind {
        case .cmake: return .cpp
        case .make: return .c
        case .cargo, .other: return .rust
        }
    }

    static func untitledName(for language: BufferLanguage) -> String {
        "untitled.\(language.fileExtension)"
    }
}
