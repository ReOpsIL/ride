import Foundation

final class AIChatStore: ObservableObject {
    static let shared = AIChatStore()
    static let flushDelay = 0.05

    @Published private(set) var threads: [AIChatThread] = []
    @Published private(set) var currentID: UUID?
    @Published var pending: [AIChatAttachment] = []
    @Published var input = ""
    @Published var focusInput = false
    @Published private(set) var streaming = false
    private var handle: AIStreamHandle?
    private var target: (thread: UUID, message: UUID)?
    private var buffered = ""
    private var flushWork: DispatchWorkItem?

    var current: AIChatThread? {
        threads.first { $0.id == currentID }
    }

    func newThread() {
        stop()
        if let current, current.messages.isEmpty {
            return
        }
        let thread = AIChatThread(title: "New chat")
        threads.insert(thread, at: 0)
        currentID = thread.id
    }

    func select(_ id: UUID) {
        guard id != currentID else {
            return
        }
        stop()
        currentID = id
    }

    func delete(_ id: UUID) {
        if id == currentID {
            stop()
        }
        threads.removeAll { $0.id == id }
        if currentID == id {
            currentID = threads.first?.id
        }
    }

    func restore(_ saved: [AIChatThread], current: UUID?) {
        stop()
        threads = saved
        currentID = current ?? saved.first?.id
    }

    func attach(_ attachments: [AIChatAttachment]) {
        for attachment in attachments where !pending.contains(attachment) {
            pending.append(attachment)
        }
    }

    func detach(_ id: UUID) {
        pending.removeAll { $0.id == id }
    }

    func send(_ question: String, config: AIConfig, attachments extra: [AIChatAttachment] = []) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        stop()
        if current == nil {
            newThread()
        }
        guard let threadID = currentID, let index = threads.firstIndex(where: { $0.id == threadID }) else {
            return
        }
        if threads[index].messages.isEmpty {
            threads[index].title = AIChatPrompt.title(for: text)
        }
        threads[index].messages.append(AIChatMessage(role: .user, text: text, attachments: pending + extra))
        let turns = AIChatPrompt.turns(threads[index].messages)
        let answer = AIChatMessage(role: .assistant, text: "", streaming: true)
        threads[index].messages.append(answer)
        pending = []
        input = ""
        target = (threadID, answer.id)
        streaming = true
        handle = AIStreamClient.stream(system: AIChatPrompt.system, turns: turns, config: config) { [weak self] event in
            self?.receive(event)
        }
    }

    func stop() {
        guard handle != nil else {
            return
        }
        handle?.cancel()
        finish(error: nil, stopped: true)
    }

    private func receive(_ event: AIStreamEvent) {
        switch event {
        case .text(let text):
            buffered += text
            scheduleFlush()
        case .finished:
            finish(error: nil, stopped: false)
        case .failed(let error):
            finish(error: error.message, stopped: false)
        }
    }

    private func scheduleFlush() {
        guard flushWork == nil else {
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        flushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flushDelay, execute: work)
    }

    private func flush() {
        flushWork?.cancel()
        flushWork = nil
        guard !buffered.isEmpty else {
            return
        }
        let text = buffered
        buffered = ""
        updateTarget { $0.text += text }
    }

    private func finish(error: String?, stopped: Bool) {
        flush()
        updateTarget { message in
            message.streaming = false
            if let error {
                message.error = error
            } else if stopped, message.text.isEmpty {
                message.error = "Stopped"
            }
        }
        handle = nil
        target = nil
        streaming = false
    }

    private func updateTarget(_ change: (inout AIChatMessage) -> Void) {
        guard let target,
              let t = threads.firstIndex(where: { $0.id == target.thread }),
              let m = threads[t].messages.firstIndex(where: { $0.id == target.message })
        else {
            return
        }
        change(&threads[t].messages[m])
    }
}
