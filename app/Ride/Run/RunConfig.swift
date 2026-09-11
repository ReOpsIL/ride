import Foundation

enum Sanitizer: String, Codable, CaseIterable {
    case address
    case undefined
    case thread
}

enum RunProjectKind: String, Codable, CaseIterable {
    case cargo
    case cmake
    case make
    case compileDb
    case none
}

struct RunConfig: Codable, Equatable {
    var target: String
    var args: [String]
    var env: [String: String]
    var workingDir: String?
    var rustBacktrace: Bool
    var sanitizers: Set<Sanitizer>

    init(
        target: String,
        args: [String] = [],
        env: [String: String] = [:],
        workingDir: String? = nil,
        rustBacktrace: Bool = false,
        sanitizers: Set<Sanitizer> = []
    ) {
        self.target = target
        self.args = args
        self.env = env
        self.workingDir = workingDir
        self.rustBacktrace = rustBacktrace
        self.sanitizers = sanitizers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
        args = try c.decodeIfPresent([String].self, forKey: .args) ?? []
        env = try c.decodeIfPresent([String: String].self, forKey: .env) ?? [:]
        workingDir = try c.decodeIfPresent(String.self, forKey: .workingDir)
        rustBacktrace = try c.decodeIfPresent(Bool.self, forKey: .rustBacktrace) ?? false
        sanitizers = try c.decodeIfPresent(Set<Sanitizer>.self, forKey: .sanitizers) ?? []
    }

    static func `default`(target: String, workingDir: String?) -> RunConfig {
        RunConfig(target: target, workingDir: workingDir)
    }

    static func config(for target: String, in configs: [RunConfig], workingDir: String?) -> RunConfig {
        configs.first { $0.target == target } ?? .default(target: target, workingDir: workingDir)
    }

    static func merged(_ config: RunConfig, into configs: [RunConfig]) -> [RunConfig] {
        var next = configs
        if let index = next.firstIndex(where: { $0.target == config.target }) {
            next[index] = config
        } else {
            next.append(config)
        }
        return next
    }
}
