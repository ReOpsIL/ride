import Foundation

private var crashExceptionPath: String?

enum ReportPaths {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Ride/reports", isDirectory: true)
    }
}

enum CrashReporter {
    static func install() {
        let directory = ReportPaths.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        let path = directory
            .appendingPathComponent("\(ReportStore.crashPrefix)\(stamp).txt")
            .path
        crashExceptionPath = path
        NSSetUncaughtExceptionHandler(crashExceptionHandler)
        CrashSignals.install(path: path)
    }
}

private func crashExceptionHandler(_ exception: NSException) {
    guard let path = crashExceptionPath else {
        return
    }
    var report = "Ride exception: \(exception.name.rawValue)\n"
    if let reason = exception.reason {
        report += reason + "\n"
    }
    report += exception.callStackSymbols.joined(separator: "\n") + "\n"
    guard let data = report.data(using: .utf8) else {
        return
    }
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
        return
    }
    try? data.write(to: URL(fileURLWithPath: path))
}
