import Darwin
import Foundation

struct SpawnedProcess {
    let pid: pid_t
    let output: FileHandle
}

enum ProcessSpawn {
    static func launch(
        executable: String,
        arguments: [String],
        environment: [String: String],
        workingDir: String?
    ) throws -> SpawnedProcess {
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var actions = fileActions(output: fds[1], workingDir: workingDir)
        var attributes = spawnAttributes()
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
            close(fds[1])
        }
        let argv = [executable] + arguments
        let envp = environment.map { "\($0.key)=\($0.value)" }
        var pid: pid_t = 0
        let result = withCStrings(argv) { cArgv in
            withCStrings(envp) { cEnvp in
                posix_spawn(&pid, executable, &actions, &attributes, cArgv, cEnvp)
            }
        }
        guard result == 0 else {
            close(fds[0])
            throw POSIXError(POSIXErrorCode(rawValue: result) ?? .EIO)
        }
        return SpawnedProcess(pid: pid, output: FileHandle(fileDescriptor: fds[0], closeOnDealloc: true))
    }

    static func finish(status: Int32) -> RunFinish {
        let signal = status & 0x7f
        guard signal != 0 else {
            return .exited((status >> 8) & 0xff)
        }
        return .signalled(signal)
    }

    private static func fileActions(output: Int32, workingDir: String?) -> posix_spawn_file_actions_t? {
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, output, 1)
        posix_spawn_file_actions_adddup2(&actions, output, 2)
        if let workingDir {
            posix_spawn_file_actions_addchdir_np(&actions, workingDir)
        }
        return actions
    }

    private static func spawnAttributes() -> posix_spawnattr_t? {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        let flags = POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))
        posix_spawnattr_setpgroup(&attributes, 0)
        var all = sigset_t()
        sigfillset(&all)
        posix_spawnattr_setsigdefault(&attributes, &all)
        var none = sigset_t()
        sigemptyset(&none)
        posix_spawnattr_setsigmask(&attributes, &none)
        return attributes
    }

    private static func withCStrings<R>(_ strings: [String], _ body: ([UnsafeMutablePointer<CChar>?]) -> R) -> R {
        let pointers = strings.map { strdup($0) } + [nil]
        defer {
            pointers.forEach { free($0) }
        }
        return body(pointers)
    }
}
