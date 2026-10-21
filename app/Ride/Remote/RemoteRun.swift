import Darwin
import Foundation

final class RemoteRun {
    private let queue = DispatchQueue(label: "ride.remote.run")
    private let runner = ProcessRunner()
    private let lock = NSLock()
    private var run = 0
    private var cancel = 0
    private var packPid: pid_t = 0
    private var unpackPid: pid_t = 0
    private var delivered = false
    private var hooks = RemoteRunHooks(onLine: { _, _ in }, onCommand: { _ in }, onFinish: { _ in })

    func start(link: RemoteLink, invocation: RunInvocation, runId: Int, hooks: RemoteRunHooks) {
        let stamp = begin(hooks)
        queue.async { [weak self] in
            self?.perform(stamp, link: link, invocation: invocation, runId: runId)
        }
    }

    func sync(link: RemoteLink, runId: Int, hooks: RemoteRunHooks) {
        let stamp = begin(hooks)
        queue.async { [weak self] in
            self?.perform(stamp, link: link, invocation: nil, runId: runId)
        }
    }

    func stop() {
        let pids = markStopped()
        if pids.pack > 0 {
            killpg(pids.pack, SIGTERM)
        }
        if pids.unpack > 0 {
            killpg(pids.unpack, SIGTERM)
        }
        runner.stop()
    }

    private func perform(_ stamp: (run: Int, cancel: Int), link: RemoteLink, invocation: RunInvocation?, runId: Int) {
        guard transfer(stamp, link: link, runId: runId) else {
            return
        }
        guard let invocation else {
            deliver(stamp.run, .exited(0))
            return
        }
        guard live(stamp) else {
            deliver(stamp.run, .signalled(SIGTERM))
            return
        }
        launch(stamp, link: link, invocation: invocation, runId: runId)
    }

    private func transfer(_ stamp: (run: Int, cancel: Int), link: RemoteLink, runId: Int) -> Bool {
        emit(runId, "sync")
        let job: (pack: RunInvocation, unpack: RunInvocation)
        do {
            job = try RemoteLaunch.sync(link)
        } catch {
            deliver(stamp.run, .failed(RemoteLaunch.explain(error)))
            return false
        }
        let piped: PipedRun
        do {
            piped = try ProcessPipe.launch(pack: job.pack, unpack: job.unpack)
        } catch {
            deliver(stamp.run, .failed(RemoteLaunch.explain(error)))
            return false
        }
        guard remember(stamp, pack: piped.pack, unpack: piped.unpack) else {
            killpg(piped.pack, SIGTERM)
            killpg(piped.unpack, SIGTERM)
            _ = ProcessPipe.wait(piped.pack)
            _ = ProcessPipe.wait(piped.unpack)
            deliver(stamp.run, .signalled(SIGTERM))
            return false
        }
        ProcessPipe.drain(piped.output) { line in
            self.emit(runId, line)
        }
        let pack = ProcessPipe.wait(piped.pack)
        let unpack = ProcessPipe.wait(piped.unpack)
        forget()
        let status = pack.succeeded ? unpack : pack
        guard status.succeeded else {
            deliver(stamp.run, status)
            return false
        }
        return true
    }

    private func launch(_ stamp: (run: Int, cancel: Int), link: RemoteLink, invocation: RunInvocation, runId: Int) {
        let wrapped: RunInvocation
        do {
            wrapped = try RemoteLaunch.command(link, invocation)
        } catch {
            deliver(stamp.run, .failed(RemoteLaunch.explain(error)))
            return
        }
        DispatchQueue.main.sync {
            guard self.live(stamp) else {
                self.deliver(stamp.run, .signalled(SIGTERM))
                return
            }
            self.hooks.onCommand(wrapped.argv.joined(separator: " "))
            self.runner.start(wrapped, runId: runId, onLine: self.hooks.onLine) { finish in
                self.deliver(stamp.run, finish)
            }
        }
    }

    private func emit(_ runId: Int, _ line: String) {
        lock.lock()
        let hook = hooks.onLine
        lock.unlock()
        DispatchQueue.main.async {
            hook(runId, line)
        }
    }

    private func begin(_ hooks: RemoteRunHooks) -> (run: Int, cancel: Int) {
        lock.lock()
        run += 1
        cancel += 1
        delivered = false
        packPid = 0
        unpackPid = 0
        self.hooks = hooks
        let stamp = (run, cancel)
        lock.unlock()
        return stamp
    }

    private func markStopped() -> (pack: pid_t, unpack: pid_t) {
        lock.lock()
        cancel += 1
        let pids = (packPid, unpackPid)
        lock.unlock()
        return pids
    }

    private func live(_ stamp: (run: Int, cancel: Int)) -> Bool {
        lock.lock()
        let live = run == stamp.run && cancel == stamp.cancel
        lock.unlock()
        return live
    }

    private func remember(_ stamp: (run: Int, cancel: Int), pack: pid_t, unpack: pid_t) -> Bool {
        lock.lock()
        let live = run == stamp.run && cancel == stamp.cancel
        if live {
            packPid = pack
            unpackPid = unpack
        }
        lock.unlock()
        return live
    }

    private func forget() {
        lock.lock()
        packPid = 0
        unpackPid = 0
        lock.unlock()
    }

    private func deliver(_ runId: Int, _ finish: RunFinish) {
        lock.lock()
        if delivered || run != runId {
            lock.unlock()
            return
        }
        delivered = true
        let hook = hooks.onFinish
        lock.unlock()
        DispatchQueue.main.async {
            hook(finish)
        }
    }
}
