import Foundation

final class SymbolPickerModel: ObservableObject {
    @Published var query = ""
    @Published var hits: [CompletionHit] = []
    @Published var selection: Int?
    private var latest: UInt64 = 0
    private var work: DispatchWorkItem?

    func reset() {
        query = ""
        hits = []
        selection = nil
        latest += 1
    }

    func refresh() {
        work?.cancel()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let engine = RideEngineClient.shared.engine else {
            hits = []
            selection = nil
            return
        }
        latest += 1
        let id = latest
        let q = CompletionQuery(
            queryId: id,
            sessionId: 0,
            prefix: text,
            mode: .items,
            context: .unknown,
            cursorByte: 0,
            replaceStartByte: 0,
            currentCrate: nil,
            currentModule: nil,
            kindFilter: nil,
            limit: 50
        )
        let work = DispatchWorkItem { [weak self] in
            let resp = engine.queryCompletions(q: q)
            DispatchQueue.main.async {
                guard let self, resp.queryId == self.latest else {
                    return
                }
                self.hits = resp.hits.filter { $0.itemKind != .keyword }
                self.selection = self.hits.isEmpty ? nil : 0
            }
        }
        self.work = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    var selected: CompletionHit? {
        guard let i = selection, hits.indices.contains(i) else {
            return hits.first
        }
        return hits[i]
    }

    func move(_ delta: Int) {
        guard !hits.isEmpty else {
            return
        }
        let current = selection ?? 0
        selection = (current + delta + hits.count) % hits.count
    }
}
