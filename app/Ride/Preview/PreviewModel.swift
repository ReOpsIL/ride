import Foundation

final class PreviewModel: ObservableObject {
    @Published var html = ""
    @Published var visibleLine = 1
    private var generation = 0
    private var work: DispatchWorkItem?

    func schedule(text: String, delay: TimeInterval = 0.25) {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.render(text: text)
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func render(text: String) {
        generation += 1
        let gen = generation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let body = RideEngineClient.shared.engine?.renderMarkdown(text: text) ?? ""
            DispatchQueue.main.async {
                guard let self, gen == self.generation else {
                    return
                }
                self.html = body
            }
        }
    }

    func cancel() {
        work?.cancel()
        generation += 1
    }
}
