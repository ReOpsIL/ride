import Darwin
import Foundation

final class ProcessSession {
    static let eofGrace = 0.5
    static let killGrace = 3.0
    static let reapPoll = 0.2

    let pid: pid_t
    var onLines: (([String]) -> Void)?
    var onFinish: ((RunFinish) -> Void)?
    private let output: FileHandle
    private let queue: DispatchQueue
    private var splitter = LineSplitter()
    private var exitStatus: RunFinish?
    private var reachedEOF = false
    private var finished = false
    private var exitSource: DispatchSourceProcess?

    init(_ spawned: SpawnedProcess, queue: DispatchQueue) {
        pid = spawned.pid
        output = spawned.output
        self.queue = queue
    }

    func start() {
        output.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.queue.async {
                self?.receive(data)
            }
        }
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: queue)
        source.setEventHandler { [weak self] in
            self?.reap()
        }
        exitSource = source
        source.resume()
        queue.async { [self] in
            reap()
        }
    }

    func stop() {
        queue.async { [self] in
            guard !finished else {
                return
            }
            killpg(pid, SIGTERM)
            pollReap()
            queue.asyncAfter(deadline: .now() + Self.killGrace) { [self] in
                if !finished {
                    killpg(pid, SIGKILL)
                }
            }
        }
    }

    private func receive(_ data: Data) {
        guard !finished else {
            return
        }
        guard !data.isEmpty else {
            reachedEOF = true
            output.readabilityHandler = nil
            pollReap()
            return
        }
        let lines = splitter.take([UInt8](data))
        if !lines.isEmpty {
            onLines?(lines)
        }
    }

    private func pollReap() {
        reap()
        guard exitStatus == nil else {
            finishIfDone(force: false)
            return
        }
        queue.asyncAfter(deadline: .now() + Self.reapPoll) { [weak self] in
            self?.pollReap()
        }
    }

    private func reap() {
        guard exitStatus == nil else {
            return
        }
        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)
        guard result != 0 else {
            return
        }
        exitStatus = result == pid ? ProcessSpawn.finish(status: status) : .failed("lost process \(pid)")
        exitSource?.cancel()
        exitSource = nil
        finishIfDone(force: false)
        queue.asyncAfter(deadline: .now() + Self.eofGrace) { [self] in
            finishIfDone(force: true)
        }
    }

    private func finishIfDone(force: Bool) {
        guard !finished, let status = exitStatus, reachedEOF || force else {
            return
        }
        finished = true
        output.readabilityHandler = nil
        let tail = splitter.finish()
        if !tail.isEmpty {
            onLines?(tail)
        }
        onFinish?(status)
    }
}
