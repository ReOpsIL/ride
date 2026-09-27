import Foundation

struct RunInvocation: Equatable {
    var argv: [String]
    var workingDir: String?
    var env: [String: String]

    init(argv: [String], workingDir: String? = nil, env: [String: String] = [:]) {
        self.argv = argv
        self.workingDir = workingDir
        self.env = env
    }
}

struct RunRequest: Equatable {
    enum Session: Equatable {
        case plain
        case build(kind: RunProjectKind, baseDir: String)
        case tests(framework: TestMarkerFramework?)
        case singleFile(baseDir: String)
    }

    var invocation: RunInvocation
    var session: Session
    var then: RunFollowUp = .none

    static func plain(_ invocation: RunInvocation) -> RunRequest {
        RunRequest(invocation: invocation, session: .plain)
    }

    func followed(by next: RunFollowUp) -> RunRequest {
        var copy = self
        switch then {
        case .none:
            copy.then = next
        case let .run(request):
            copy.then = .run(request.followed(by: next))
        case .debug:
            break
        }
        return copy
    }
}

indirect enum RunFollowUp: Equatable {
    case none
    case run(RunRequest)
    case debug
}
