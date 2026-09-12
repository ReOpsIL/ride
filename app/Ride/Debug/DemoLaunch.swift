import AppKit

enum DemoLaunch {
    static var scene: String? {
        value(after: "--demo")
    }

    static var isDemo: Bool {
        scene != nil
    }

    static var theme: String? {
        value(after: "--theme")
    }

    static var file: String? {
        value(after: "--file")
    }

    static var report: String? {
        value(after: "--report")
    }

    static var readyFile: String? {
        value(after: "--ready-file")
    }

    static var quitAfter: Double? {
        guard let raw = value(after: "--quit-after") else {
            return nil
        }
        return Double(raw)
    }

    static var scroll: Bool {
        CommandLine.arguments.contains("--scroll")
    }

    static var frame: NSSize? {
        guard let raw = value(after: "--frame") else {
            return nil
        }
        let parts = raw.lowercased().split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else {
            return nil
        }
        return NSSize(width: parts[0], height: parts[1])
    }

    static func start(state: AppState) {
        if let size = frame {
            after(0.3) { resize(to: size) }
        }
        armQuitGuard()
        guard let scene else {
            return
        }
        after(1.0) { DemoScene.run(scene, state: state) }
    }

    static func ready() {
        after(0.6) {
            writeReadyFile()
            armQuit()
        }
    }

    static func activate() {
        guard readyFile != nil else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
    }

    static func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private static let guardSeconds = 600.0

    private static func armQuitGuard() {
        guard quitAfter != nil else {
            return
        }
        after(guardSeconds) { NSApp.terminate(nil) }
    }

    private static func armQuit() {
        guard let seconds = quitAfter else {
            return
        }
        after(seconds) { NSApp.terminate(nil) }
    }

    private static func writeReadyFile() {
        guard let path = readyFile else {
            return
        }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? "ready\n".write(to: url, atomically: true, encoding: .utf8)
    }

    private static func resize(to size: NSSize) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) else {
            return
        }
        window.setContentSize(size)
        window.center()
    }

    private static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else {
            return nil
        }
        return args[i + 1]
    }
}
