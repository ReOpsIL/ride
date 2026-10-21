import Darwin
import Foundation

struct PipedRun {
    let pack: pid_t
    let unpack: pid_t
    let output: FileHandle
}

enum PipeError: Error {
    case missing(String)
}

enum ProcessPipe {
    static func launch(pack: RunInvocation, unpack: RunInvocation) throws -> PipedRun {
        let packURL = try executable(pack)
        let unpackURL = try executable(unpack)
        let bridge = try ends()
        let output: (Int32, Int32)
        do {
            output = try ends()
        } catch {
            close(bridge.0)
            close(bridge.1)
            throw error
        }
        defer {
            close(bridge.0)
            close(bridge.1)
            close(output.1)
        }
        let environment = localEnvironment()
        let packPid: pid_t
        do {
            packPid = try child(packURL, pack, environment, input: nil, output: bridge.1, error: output.1)
        } catch {
            close(output.0)
            throw error
        }
        do {
            let unpackPid = try child(unpackURL, unpack, environment, input: bridge.0, output: output.1, error: output.1)
            return PipedRun(
                pack: packPid,
                unpack: unpackPid,
                output: FileHandle(fileDescriptor: output.0, closeOnDealloc: true)
            )
        } catch {
            killpg(packPid, SIGKILL)
            _ = wait(packPid)
            close(output.0)
            throw error
        }
    }

    static func wait(_ pid: pid_t) -> RunFinish {
        while true {
            var status: Int32 = 0
            let result = waitpid(pid, &status, 0)
            if result == pid {
                return ProcessSpawn.finish(status: status)
            }
            if result == -1, errno == EINTR {
                continue
            }
            return .failed("lost process \(pid)")
        }
    }

    static func drain(_ handle: FileHandle, emit: (String) -> Void) {
        var splitter = LineSplitter()
        while true {
            let data = handle.availableData
            if data.isEmpty {
                break
            }
            splitter.take([UInt8](data)).forEach(emit)
        }
        splitter.finish().forEach(emit)
    }

    private static func child(
        _ executable: String,
        _ invocation: RunInvocation,
        _ environment: [String: String],
        input: Int32?,
        output: Int32,
        error: Int32
    ) throws -> pid_t {
        try ProcessSpawn.spawn(
            executable: executable,
            arguments: Array(invocation.argv.dropFirst()),
            environment: environment,
            workingDir: invocation.workingDir,
            input: input,
            output: output,
            error: error
        )
    }

    private static func executable(_ invocation: RunInvocation) throws -> String {
        guard let tool = invocation.argv.first, let url = ProcessLookup.url(for: tool, workingDir: invocation.workingDir) else {
            throw PipeError.missing(invocation.argv.first ?? "command")
        }
        return url.path
    }

    private static func ends() throws -> (Int32, Int32) {
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return (fds[0], fds[1])
    }

    private static func localEnvironment() -> [String: String] {
        ProcessInfo.processInfo.environment.merging(["PATH": ShellPath.value]) { _, new in new }
    }
}
