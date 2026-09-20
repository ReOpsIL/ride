import Foundation

enum UsageIndexer {
    private static let queue = DispatchQueue(label: "ride.usages.index", qos: .utility)

    static func index(sessionId: UInt64) {
        queue.async {
            _ = try? RideEngineClient.shared.engine?.noteSaved(sessionId: sessionId)
            DispatchQueue.main.async {
                UsageCounter.refresh(sessionId: sessionId)
            }
        }
    }

    static func index(_ documents: [BufferDocument]) {
        let ids = documents.compactMap(\.sessionId)
        guard !ids.isEmpty else {
            return
        }
        queue.async {
            for id in ids {
                _ = try? RideEngineClient.shared.engine?.noteSaved(sessionId: id)
            }
            DispatchQueue.main.async {
                for document in documents {
                    UsageCounter.refresh(document: document)
                }
            }
        }
    }
}
