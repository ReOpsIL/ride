import Foundation

final class TestRunStore: ObservableObject {
    static let shared = TestRunStore()

    @Published private(set) var tree = TestTree()
    @Published var filter = ""
    @Published var selected: String?
    @Published private(set) var running = false
    @Published private(set) var status: String?
    @Published private(set) var command: String?

    func begin(command: String?) {
        tree.clear()
        selected = nil
        status = nil
        running = true
        self.command = command
    }

    func apply(_ events: [TestEvent]) {
        var next = TestTree()
        for event in events {
            next.apply(Self.row(event))
        }
        guard next != tree else {
            return
        }
        tree = next
    }

    func finish(_ status: String?) {
        running = false
        self.status = status
    }

    func clear() {
        tree.clear()
        selected = nil
        status = nil
        command = nil
    }

    static func row(_ event: TestEvent) -> TestRow {
        TestRow(
            suite: event.suite ?? "",
            name: event.name,
            outcome: outcome(event.status),
            output: event.output,
            durationMs: event.durationMs
        )
    }

    private static func outcome(_ status: TestStatus) -> TestOutcome {
        switch status {
        case .started:
            return .running
        case .passed:
            return .passed
        case .failed:
            return .failed
        case .ignored:
            return .ignored
        }
    }
}
