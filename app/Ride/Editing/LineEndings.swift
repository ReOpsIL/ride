import Foundation

enum LineEndings {
    static let keep = "keep"
    static let lf = "lf"

    struct Encoded: Equatable {
        let text: String
        let usesCRLF: Bool
    }

    static func normalized(_ text: String) -> String {
        guard text.utf8.contains(13) else {
            return text
        }
        return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    static func encode(text: String, usesCRLF: Bool, policy: String) -> Encoded {
        if policy == lf {
            return Encoded(text: text, usesCRLF: false)
        }
        let output = usesCRLF ? text.replacingOccurrences(of: "\n", with: "\r\n") : text
        return Encoded(text: output, usesCRLF: usesCRLF)
    }
}
