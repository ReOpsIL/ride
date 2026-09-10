import Foundation

struct CommentTokens: Equatable {
    let line: String?
    let blockOpen: String?
    let blockClose: String?

    static let none = CommentTokens(line: nil, blockOpen: nil, blockClose: nil)

    static func tokens(for language: BufferLanguage) -> CommentTokens {
        switch language {
        case .rust, .c, .cpp:
            return CommentTokens(line: "//", blockOpen: "/*", blockClose: "*/")
        case .toml, .make, .cmake:
            return CommentTokens(line: "#", blockOpen: nil, blockClose: nil)
        case .markdown:
            return CommentTokens(line: nil, blockOpen: "<!--", blockClose: "-->")
        case .plain:
            return none
        }
    }
}
