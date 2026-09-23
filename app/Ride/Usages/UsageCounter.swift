import Foundation

enum UsageCounter {
    static let nameCap = 200
    private static var pending: [ObjectIdentifier: DispatchWorkItem] = [:]

    static func refresh(sessionId: UInt64) {
        let document = EditorPanes.shared.all.first { $0.document?.sessionId == sessionId }?.document
        guard let document else {
            return
        }
        refresh(document: document)
    }

    static func refresh(document: BufferDocument) {
        let key = ObjectIdentifier(document)
        pending[key]?.cancel()
        let work = DispatchWorkItem {
            pending[key] = nil
            fetch(document: document)
        }
        pending[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private static func fetch(document: BufferDocument) {
        guard let id = document.sessionId else {
            return
        }
        let enabled = EditorPanes.shared.host(bound: document)?.textView.showCodeVision ?? true
        if !enabled {
            apply([:], to: document)
            return
        }
        let names = uniqueNames(document.outline)
        document.visionGeneration += 1
        let token = document.visionGeneration
        _ = RideEngineClient.shared.withEngine(qos: .utility, { engine in
            engine.usageCounts(sessionId: id, names: names)
        }, then: { counts in
            guard document.visionGeneration == token, document.sessionId == id else {
                return
            }
            apply(zipped(names, counts), to: document)
        })
    }

    static func uniqueNames(_ rows: [OutlineRow]) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for row in rows where seen.insert(row.name).inserted {
            names.append(row.name)
            if names.count == nameCap {
                break
            }
        }
        return names
    }

    private static func zipped(_ names: [String], _ counts: [UInt32]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, name) in names.enumerated() {
            map[name] = i < counts.count ? Int(counts[i]) : 0
        }
        return map
    }

    private static func apply(_ map: [String: Int], to document: BufferDocument) {
        guard document.visionCounts != map else {
            return
        }
        let view = EditorPanes.shared.host(bound: document)?.textView
        let before = view?.visionLines() ?? []
        document.visionCounts = map
        view?.refreshVision(from: before)
    }
}
