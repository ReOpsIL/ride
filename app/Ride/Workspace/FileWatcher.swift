import CoreServices
import Foundation

final class FileWatcher {
    static let coalesceDelay = 0.3

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "dev.ride.fs")
    private var pending: [String] = []
    private var flushScheduled = false
    var handler: (([String]) -> Void)?

    var isWatching: Bool {
        stream != nil
    }

    func start(path: String) {
        stop()
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else {
                return
            }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            watcher.collect(paths)
        }
        let paths = [path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagUseCFTypes
        )
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            flags
        ) else {
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func collect(_ paths: [String]) {
        pending.append(contentsOf: paths)
        guard !flushScheduled else {
            return
        }
        flushScheduled = true
        queue.asyncAfter(deadline: .now() + Self.coalesceDelay) { [weak self] in
            self?.flush()
        }
    }

    private func flush() {
        flushScheduled = false
        var seen = Set<String>()
        let batch = pending.filter { seen.insert($0).inserted }
        pending = []
        guard !batch.isEmpty else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.handler?(batch)
        }
    }

    func stop() {
        guard let stream else {
            return
        }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
