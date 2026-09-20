import Darwin

private let crashFrameCapacity: Int32 = 64
private var crashReportPath: UnsafeMutablePointer<CChar>?
private var crashFrames: UnsafeMutablePointer<UnsafeMutableRawPointer?>?

enum CrashSignals {
    static let handled: [Int32] = [SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT]

    static func install(path: String) {
        crashReportPath = strdup(path)
        crashFrames = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(
            capacity: Int(crashFrameCapacity)
        )
        for number in handled {
            signal(number, crashSignalHandler)
        }
    }
}

private func crashSignalHandler(_ number: Int32) {
    if let path = crashReportPath, let frames = crashFrames {
        let descriptor = open(path, O_WRONLY | O_CREAT | O_APPEND, 0o600)
        if descriptor >= 0 {
            crashWrite(descriptor, crashSignalName(number))
            let depth = backtrace(frames, crashFrameCapacity)
            backtrace_symbols_fd(frames, depth, descriptor)
            close(descriptor)
        }
    }
    signal(number, SIG_DFL)
    raise(number)
}

private func crashWrite(_ descriptor: Int32, _ text: StaticString) {
    _ = write(descriptor, text.utf8Start, text.utf8CodeUnitCount)
}

private func crashSignalName(_ number: Int32) -> StaticString {
    switch number {
    case SIGSEGV:
        return "Ride crash: SIGSEGV\n"
    case SIGBUS:
        return "Ride crash: SIGBUS\n"
    case SIGILL:
        return "Ride crash: SIGILL\n"
    case SIGFPE:
        return "Ride crash: SIGFPE\n"
    case SIGABRT:
        return "Ride crash: SIGABRT\n"
    default:
        return "Ride crash: signal\n"
    }
}
