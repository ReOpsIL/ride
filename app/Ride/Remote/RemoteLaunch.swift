import Foundation

enum RemoteLaunch {
    static func sync(_ link: RemoteLink) throws -> (pack: RunInvocation, unpack: RunInvocation) {
        let job = try engine().remoteSync(link: link)
        return (invocation(job.pack), invocation(job.unpack))
    }

    static func command(_ link: RemoteLink, _ invocation: RunInvocation) throws -> RunInvocation {
        let cwd = invocation.workingDir ?? link.localRoot
        let built = try engine().remoteCommand(link: link, cwd: cwd, env: invocation.env, argv: invocation.argv)
        return RunInvocation(argv: [built.program] + built.args)
    }

    static func probe(_ link: RemoteLink) throws -> RunInvocation {
        invocation(try engine().remoteProbe(link: link))
    }

    static func report(_ link: RemoteLink, output: String) throws -> [RemoteCheck] {
        try engine().remoteProbeReport(link: link, output: output)
    }

    static func link(for toolchain: RemoteToolchain, localRoot: String) -> RemoteLink {
        RemoteLink(
            kind: reach(toolchain.kind),
            user: trimmed(toolchain.user),
            host: trimmed(toolchain.host),
            port: toolchain.port,
            identity: (trimmed(toolchain.identity) as NSString).expandingTildeInPath,
            proxyCommand: trimmed(toolchain.proxy),
            localRoot: localRoot,
            remoteRoot: trimmed(toolchain.remoteRoot),
            name: trimmed(toolchain.name),
            namespace: trimmed(toolchain.namespace),
            container: trimmed(toolchain.container)
        )
    }

    static func explain(_ error: Error) -> String {
        if case let PipeError.missing(tool) = error {
            return "command not found: \(tool)"
        }
        guard let error = error as? EngineError else {
            return error.localizedDescription
        }
        if case let .Remote(message) = error {
            return message
        }
        return String(describing: error)
    }

    private static func engine() throws -> Engine {
        guard let engine = RideEngineClient.shared.engine else {
            throw PipeError.missing("engine")
        }
        return engine
    }

    private static func invocation(_ command: RemoteCommand) -> RunInvocation {
        RunInvocation(argv: [command.program] + command.args)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func reach(_ kind: RemoteKind) -> RemoteReach {
        switch kind {
        case .vm: .vm
        case .container: .container
        case .pod: .pod
        case .docker: .docker
        }
    }
}
