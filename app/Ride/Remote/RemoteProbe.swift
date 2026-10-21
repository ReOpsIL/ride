import Darwin
import Foundation

enum RemoteProbeResult {
    case output(String)
    case timedOut
    case failed(String)
}

final class RemoteProbe {
    static let limit: TimeInterval = 30

    private let queue = DispatchQueue(label: "ride.remote.probe")
    private let lock = NSLock()
    private var generation = 0
    private var pid: pid_t = 0
    private var expired = false

    func start(_ invocation: RunInvocation, finish: @escaping (RemoteProbeResult) -> Void) {
        let stamp = begin()
        queue.async { [weak self] in
            guard let self else {
                return
            }
            let result = self.run(invocation, stamp: stamp)
            DispatchQueue.main.async {
                if self.current(stamp) {
                    finish(result)
                }
            }
        }
        queue.asyncAfter(deadline: .now() + Self.limit) { [weak self] in
            self?.expire(stamp)
        }
    }

    func stop() {
        lock.lock()
        generation += 1
        let running = pid
        lock.unlock()
        if running > 0 {
            killpg(running, SIGTERM)
        }
    }

    private func run(_ invocation: RunInvocation, stamp: Int) -> RemoteProbeResult {
        guard let tool = invocation.argv.first, let url = ProcessLookup.url(for: tool, workingDir: nil) else {
            return .failed("command not found: \(invocation.argv.first ?? "ssh")")
        }
        let spawned: SpawnedProcess
        do {
            spawned = try ProcessSpawn.launch(
                executable: url.path,
                arguments: Array(invocation.argv.dropFirst()),
                environment: ProcessInfo.processInfo.environment.merging(["PATH": ShellPath.value]) { _, new in new },
                workingDir: nil
            )
        } catch {
            return .failed(error.localizedDescription)
        }
        remember(spawned.pid, stamp: stamp)
        let data = spawned.output.readDataToEndOfFile()
        _ = ProcessPipe.wait(spawned.pid)
        return settle(stamp) ? .timedOut : .output(String(decoding: data, as: UTF8.self))
    }

    private func begin() -> Int {
        lock.lock()
        generation += 1
        pid = 0
        expired = false
        let stamp = generation
        lock.unlock()
        return stamp
    }

    private func remember(_ spawned: pid_t, stamp: Int) {
        lock.lock()
        let live = generation == stamp
        if live {
            pid = spawned
        }
        lock.unlock()
        if !live {
            killpg(spawned, SIGTERM)
        }
    }

    private func settle(_ stamp: Int) -> Bool {
        lock.lock()
        let timedOut = generation == stamp && expired
        if generation == stamp {
            pid = 0
        }
        lock.unlock()
        return timedOut
    }

    private func expire(_ stamp: Int) {
        lock.lock()
        let running = generation == stamp ? pid : 0
        if running > 0 {
            expired = true
        }
        lock.unlock()
        if running > 0 {
            killpg(running, SIGTERM)
        }
    }

    private func current(_ stamp: Int) -> Bool {
        lock.lock()
        let live = generation == stamp
        lock.unlock()
        return live
    }
}
