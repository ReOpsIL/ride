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

final class ProcessRunner {
    private var process: Process?
    private var killWork: DispatchWorkItem?
    private var splitter = LineSplitter()
    private let queue = DispatchQueue(label: "ride.run.output")

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(
        _ invocation: RunInvocation,
        onLine: @escaping (String) -> Void,
        onFinish: @escaping (RunFinish) -> Void
    ) {
        guard !isRunning, let tool = invocation.argv.first else {
            report(.failed("no command"), onFinish: onFinish)
            return
        }
        guard let executable = ProcessLookup.url(for: tool, workingDir: invocation.workingDir) else {
            report(.failed("command not found: \(tool)"), onFinish: onFinish)
            return
        }
        let task = Process()
        task.executableURL = executable
        task.arguments = Array(invocation.argv.dropFirst())
        task.environment = ProcessInfo.processInfo.environment.merging(invocation.env) { _, new in new }
        if let dir = invocation.workingDir {
            task.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        splitter = LineSplitter()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            self?.receive(data, onLine: onLine)
        }
        task.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let tail = try? pipe.fileHandleForReading.readToEnd()
            if let tail, !tail.isEmpty {
                self?.receive(tail, onLine: onLine)
            }
            self?.finish(finished, onLine: onLine, onFinish: onFinish)
        }
        do {
            try task.run()
            process = task
        } catch {
            process = nil
            report(.failed(error.localizedDescription), onFinish: onFinish)
        }
    }

    private func report(_ finish: RunFinish, onFinish: @escaping (RunFinish) -> Void) {
        DispatchQueue.main.async {
            onFinish(finish)
        }
    }

    func stop() {
        guard let task = process, task.isRunning else {
            return
        }
        task.terminate()
        let work = DispatchWorkItem { [weak task] in
            guard let task, task.isRunning else {
                return
            }
            kill(task.processIdentifier, SIGKILL)
        }
        killWork?.cancel()
        killWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func receive(_ data: Data, onLine: @escaping (String) -> Void) {
        let lines = queue.sync { splitter.take([UInt8](data)) }
        guard !lines.isEmpty else {
            return
        }
        DispatchQueue.main.async {
            for line in lines {
                onLine(line)
            }
        }
    }

    private func finish(_ task: Process, onLine: @escaping (String) -> Void, onFinish: @escaping (RunFinish) -> Void) {
        let tail = queue.sync { splitter.flush() }
        let status: RunFinish = task.terminationReason == .uncaughtSignal
            ? .signalled(task.terminationStatus)
            : .exited(task.terminationStatus)
        DispatchQueue.main.async { [weak self] in
            if let tail {
                onLine(tail)
            }
            self?.killWork?.cancel()
            self?.killWork = nil
            self?.process = nil
            onFinish(status)
        }
    }
}

enum ProcessLookup {
    static func url(for tool: String, workingDir: String?) -> URL? {
        if tool.contains("/") {
            if tool.hasPrefix("/") {
                return URL(fileURLWithPath: tool)
            }
            let base = workingDir ?? FileManager.default.currentDirectoryPath
            return URL(fileURLWithPath: (base as NSString).appendingPathComponent(tool))
        }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        let dirs = path.components(separatedBy: ":") + ["/usr/bin", "/bin", "/usr/local/bin", "/opt/homebrew/bin"]
        for dir in dirs where !dir.isEmpty {
            let candidate = (dir as NSString).appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
}
