import Foundation

extension TargetRowKind {
    init(_ kind: TargetKind) {
        switch kind {
        case .bin: self = .bin
        case .lib: self = .lib
        case .test: self = .test
        case .bench: self = .bench
        case .example: self = .example
        case .custom: self = .custom
        }
    }
}

extension RunTarget {
    init(_ target: Target, root: String) {
        self.init(
            name: target.name,
            kind: TargetRowKind(target.kind),
            build: target.build,
            run: target.run ?? [],
            workingDir: target.workingDir.isEmpty ? root : target.workingDir
        )
    }
}
