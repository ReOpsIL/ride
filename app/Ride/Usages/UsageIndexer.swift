import Foundation

enum UsageIndexer {
    static func index(_ documents: [BufferDocument]) {
        for document in documents {
            SessionService.shared.read(document, lane: .workspace, qos: .utility, { engine, id in
                _ = try? engine.noteSaved(sessionId: id)
            }, then: {
                UsageCounter.refresh(document: document)
            })
        }
    }
}
