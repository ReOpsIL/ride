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
