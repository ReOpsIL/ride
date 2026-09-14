import Foundation

enum DiagnosticDocLink {
    static func url(for code: String) -> URL? {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasPrefix("clippy::") {
            let name = String(trimmed.dropFirst("clippy::".count))
            return URL(string: "https://rust-lang.github.io/rust-clippy/master/index.html#\(name)")
        }
        if isRustError(trimmed) {
            return URL(string: "https://doc.rust-lang.org/error_codes/\(trimmed).html")
        }
        if trimmed.hasPrefix("-W") || trimmed.hasPrefix("-R") {
            return URL(string: "https://clang.llvm.org/docs/DiagnosticsReference.html#\(trimmed.dropFirst().lowercased())")
        }
        if let group = tidyGroup(trimmed) {
            return URL(string: "https://clang.llvm.org/extra/clang-tidy/checks/\(group.0)/\(group.1).html")
        }
        return nil
    }

    private static func isRustError(_ code: String) -> Bool {
        code.hasPrefix("E") && code.count >= 2 && code.dropFirst().allSatisfy { $0.isNumber }
    }

    private static func tidyGroup(_ code: String) -> (String, String)? {
        guard !code.contains(" "), !code.contains(":"), let dash = code.firstIndex(of: "-") else {
            return nil
        }
        let group = String(code[..<dash])
        let name = String(code[code.index(after: dash)...])
        guard !group.isEmpty, !name.isEmpty else {
            return nil
        }
        return (group, name)
    }
}
