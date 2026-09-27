import Foundation

enum SelfTestCoverage {
    static var claims: [String: [String]] {
        [fileEditClaims, codeClaims, runClaims].reduce(into: [:]) { merged, table in
            merged.merge(table) { $0 + $1 }
        }
    }

    static var exempt: [String: String] {
        [fileEditExempt, codeExempt, runExempt].reduce(into: [:]) { merged, table in
            merged.merge(table) { first, _ in first }
        }
    }
}
