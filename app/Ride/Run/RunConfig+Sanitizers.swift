import Foundation

extension RunConfig {
    static var hostTriple: String {
        #if arch(arm64)
            return "aarch64-apple-darwin"
        #else
            return "x86_64-apple-darwin"
        #endif
    }

    var orderedSanitizers: [Sanitizer] {
        Sanitizer.allCases.filter { sanitizers.contains($0) }
    }

    func requiresNightly(for kind: RunProjectKind) -> Bool {
        kind == .cargo && !sanitizers.isEmpty
    }

    func flags(for kind: RunProjectKind) -> (env: [String: String], args: [String]) {
        let names = orderedSanitizers.map(\.rawValue)
        if names.isEmpty {
            return ([:], [])
        }
        switch kind {
        case .cargo:
            let rustflags = names.map { "-Zsanitizer=\($0)" }.joined(separator: " ")
            return (["RUSTFLAGS": rustflags], ["--target", RunConfig.hostTriple])
        case .cmake:
            return ([:], ["-DCMAKE_CXX_FLAGS=-fsanitize=\(names.joined(separator: ","))"])
        case .make, .compileDb, .none:
            return ([:], [])
        }
    }
}
