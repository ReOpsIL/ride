import Foundation

struct RunVariant: Equatable {
    static let release = "release"

    var kind: RunProjectKind
    var profile: String
    var sanitizers: [Sanitizer]
    var engineDir: String?

    init(kind: RunProjectKind, profile: String, sanitizers: [Sanitizer], targets: [RunTarget] = []) {
        self.kind = kind
        self.profile = profile
        self.sanitizers = sanitizers
        engineDir = kind == .cmake ? RunVariant.buildDir(in: targets) : nil
    }

    var cargoTriple: String? {
        kind == .cargo && !sanitizers.isEmpty ? RunConfig.hostTriple : nil
    }

    var cargoProfileDir: String {
        profile == RunVariant.release ? RunVariant.release : "debug"
    }

    var cmakeProfile: String {
        profile.isEmpty ? (engineDir.map { ($0 as NSString).lastPathComponent } ?? "") : profile
    }

    var cmakeDir: String? {
        guard let engineDir else {
            return nil
        }
        let suffix = sanitizers.isEmpty ? "" : "-" + sanitizers.map(\.rawValue).joined(separator: "-")
        return (engineDir as NSString).deletingLastPathComponent + "/" + cmakeProfile + suffix
    }

    var env: [String: String] {
        guard cargoTriple != nil else {
            return [:]
        }
        return ["RUSTFLAGS": sanitizers.map { "-Zsanitizer=\($0.rawValue)" }.joined(separator: " ")]
    }

    func argv(_ argv: [String]) -> [String] {
        switch kind {
        case .cargo:
            return argv.first == "cargo" ? argv + cargoFlags : argv
        case .cmake:
            return argv.map(relocated)
        case .make, .compileDb, .none:
            return argv
        }
    }

    func configure(source: String) -> [String]? {
        guard let dir = cmakeDir, dir != engineDir else {
            return nil
        }
        return ["cmake", "-S", source, "-B", dir, "-DCMAKE_BUILD_TYPE=\(cmakeProfile)"] + cmakeFlags
    }

    static func buildDir(in targets: [RunTarget]) -> String? {
        for target in targets {
            if let index = target.build.firstIndex(of: "--build"), index + 1 < target.build.count {
                return target.build[index + 1]
            }
        }
        return nil
    }

    private var cargoFlags: [String] {
        let release = profile == RunVariant.release ? ["--release"] : []
        return release + (cargoTriple.map { ["--target", $0] } ?? [])
    }

    private var cmakeFlags: [String] {
        guard !sanitizers.isEmpty else {
            return []
        }
        let flag = "-fsanitize=" + sanitizers.map(\.rawValue).joined(separator: ",")
        return ["-DCMAKE_C_FLAGS=\(flag)", "-DCMAKE_CXX_FLAGS=\(flag)"]
    }

    private func relocated(_ arg: String) -> String {
        guard let engineDir, let dir = cmakeDir, dir != engineDir else {
            return arg
        }
        if arg == engineDir {
            return dir
        }
        return arg.hasPrefix(engineDir + "/") ? dir + arg.dropFirst(engineDir.count) : arg
    }
}
