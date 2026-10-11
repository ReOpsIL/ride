import Foundation

final class CompletionDocLoad {
    private var token = 0
    private var wait: DispatchWorkItem?

    func cancel() {
        token += 1
        wait?.cancel()
        wait = nil
    }

    func start(_ item: CompletionItem?, apply: @escaping (String) -> Void) {
        cancel()
        let current = token
        guard let hit = item?.hit, let path = hit.sourcePath, let byte = hit.nameByte ?? hit.byteStart else {
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, current == self.token else {
                return
            }
            SessionService.shared.quickDoc(path: path, byte: byte) { doc in
                guard current == self.token else {
                    return
                }
                let full = doc.map { HoverDocText.plain($0.html) } ?? ""
                if !full.isEmpty {
                    apply(full)
                }
            }
        }
        wait = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}
