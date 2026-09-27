import Foundation

extension Sanitizer {
    static func supported(by kind: RunProjectKind) -> [Sanitizer] {
        switch kind {
        case .cargo:
            return [.address, .thread]
        case .cmake:
            return allCases
        case .make, .compileDb, .none:
            return []
        }
    }

    var conflicts: Set<Sanitizer> {
        switch self {
        case .address:
            return [.thread]
        case .thread:
            return [.address]
        case .undefined:
            return []
        }
    }
}

extension RunConfig {
    static var hostTriple: String {
        #if arch(arm64)
            return "aarch64-apple-darwin"
        #else
            return "x86_64-apple-darwin"
        #endif
    }

    func activeSanitizers(for kind: RunProjectKind) -> [Sanitizer] {
        Sanitizer.supported(by: kind).filter { sanitizers.contains($0) }
    }

    func requiresNightly(for kind: RunProjectKind) -> Bool {
        kind == .cargo && !activeSanitizers(for: kind).isEmpty
    }
}
