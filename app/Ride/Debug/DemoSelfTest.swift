import AppKit

struct SelfTestStep {
    let name: String
    var wait: Double = 0.25
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
        DemoLaunch.after(step.wait) { [self] in
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
        writeReport()
        exit(results.contains(where: { $0.hasPrefix("FAIL") }) ? 1 : 0)
    }

    private func writeReport() {
        let text = results.joined(separator: "\n") + "\n"
        try? text.write(toFile: report, atomically: true, encoding: .utf8)
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

    func expect(_ condition: Bool, _ message: @autoclosure () -> String) -> String? {
        condition ? nil : message()
    }
}
