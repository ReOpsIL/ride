import Foundation

final class AIActivity: ObservableObject {
    static let shared = AIActivity()
    @Published private(set) var busy = 0
    @Published private(set) var note: String?
    private var noteWork: DispatchWorkItem?

    /// A short status-bar note about the last completion request, cleared after a few seconds.
    func report(_ text: String, seconds: Double = 5) {
        note = text
        noteWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.note = nil }
        noteWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func begin() {
        busy += 1
    }

    func end() {
        busy = max(0, busy - 1)
    }
}
