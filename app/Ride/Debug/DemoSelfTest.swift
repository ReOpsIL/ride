import AppKit

struct SelfTestStep {
    let name: String
    var wait: Double = 0.25
    var until: (() -> Bool)?
    var timeout: Double = 0
    let run: () -> Void
    let check: () -> String?
}

final class DemoSelfTest {
    static let shared = DemoSelfTest()
    private var results: [String] = []
    private var steps: [SelfTestStep] = []
    private var report = ""

    static func start(state: AppState, report: String) {
        shared.report = report
        shared.results = []
        shared.writeReport()
        shared.steps = SelfTestSteps.all(state: state)
        shared.next(state: state)
    }

    private func next(state: AppState) {
        guard !steps.isEmpty else {
            finish()
            return
        }
        let step = steps.removeFirst()
        step.run()
        settle(step, state: state, deadline: Date().addingTimeInterval(step.timeout))
    }

    private func settle(_ step: SelfTestStep, state: AppState, deadline: Date) {
        DemoLaunch.after(step.wait) { [self] in
            if let until = step.until, !until(), Date() < deadline {
                settle(step, state: state, deadline: deadline)
                return
            }
            if let failure = step.check() {
                let e = SelfTestEditor(state: state)
                let dump = (8...13).map { "\($0): \(e.line($0))" }.joined(separator: " ¶ ")
                results.append("FAIL \(step.name): \(failure) || \(dump)")
            } else {
                results.append("PASS \(step.name)")
            }
            writeReport()
            next(state: state)
        }
    }

    private func finish() {
        let code = results.contains(where: { $0.hasPrefix("FAIL") }) ? 1 : 0
        results.append("EXIT \(code)")
        writeReport()
        NSApp.terminate(nil)
    }

    private func writeReport() {
        let url = URL(fileURLWithPath: report)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let text = results.joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct SelfTestEditor {
    let state: AppState

    var view: RideTextView? {
        EditorPanes.shared.focusedView
    }

    var text: String {
        view?.string ?? ""
    }

    var lines: [String] {
        text.components(separatedBy: "\n")
    }

    func line(_ number: Int) -> String {
        lines.indices.contains(number - 1) ? lines[number - 1] : ""
    }

    func lineRange(_ number: Int) -> NSRange {
        guard let view else {
            return NSRange(location: 0, length: 0)
        }
        let starts = view.lineIndex().starts
        let start = starts[min(max(number, 1), starts.count) - 1]
        return (text as NSString).lineRange(for: NSRange(location: start, length: 0))
    }

    func caret(line number: Int, column: Int = 1) {
        let range = lineRange(number)
        view?.setSelectedRange(NSRange(location: range.location + column - 1, length: 0))
    }

    func selectLines(_ from: Int, _ to: Int) {
        let a = lineRange(from)
        let b = lineRange(to)
        view?.setSelectedRange(NSRange(location: a.location, length: NSMaxRange(b) - a.location))
    }

    var caretLine: Int {
        guard let view else {
            return 0
        }
        return view.lineIndex().line(at: view.selectedRange().location)
    }

    var selectedText: String {
        guard let view else {
            return ""
        }
        return (text as NSString).substring(with: view.selectedRange())
    }

    func focus() {
        guard let view else {
            return
        }
        view.window?.makeFirstResponder(view)
    }

    func activate() {
        guard let view else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(view)
    }

    func type(_ text: String) {
        guard let view else {
            return
        }
        for ch in text {
            let s = String(ch)
            let loc = view.selectedRange().location
            view.insertText(s, replacementRange: NSRange(location: loc, length: 0))
            view.setSelectedRange(NSRange(location: loc + (s as NSString).length, length: 0))
        }
    }

    func place(on needle: String, atEnd: Bool = false) {
        guard let view else {
            return
        }
        let range = (view.string as NSString).range(of: needle)
        guard range.location != NSNotFound else {
            return
        }
        let loc = atEnd ? NSMaxRange(range) : range.location
        view.setSelectedRange(NSRange(location: loc, length: 0))
    }

    func expect(_ condition: Bool, _ message: @autoclosure () -> String) -> String? {
        condition ? nil : message()
    }
}

final class SelfTestScratch {
    var body = ""
    var next = ""
}

struct SelfTestOpened {
    let bodyLine: Int
    let goToLine: Int
    let fileName: String
    let filePath: String

    static func from(_ state: AppState) -> SelfTestOpened {
        let url = state.activeBuffer?.fileURL
        let name = url?.lastPathComponent ?? "main.rs"
        let relative = url.flatMap { file in
            state.workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: file) }
        }
        switch state.activeBuffer?.language ?? BufferLanguage.of(url) {
        case .c, .cpp:
            return SelfTestOpened(bodyLine: 15, goToLine: 30, fileName: name, filePath: relative ?? "src/shapes.cpp")
        default:
            return SelfTestOpened(bodyLine: 10, goToLine: 15, fileName: name, filePath: relative ?? "src/main.rs")
        }
    }
}
