import AppKit

enum CompletionFetch {
    struct Request {
        let queryId: UInt64
        weak var document: BufferDocument?
        weak var view: RideTextView?
        weak var state: AppState?
    }

    static func run(_ request: Request, done: @escaping (CompletionResponse, Int) -> Void) {
        guard let view = request.view else {
            return
        }
        let text = view.string
        let caretUtf16 = view.selectedRange().location
        let cursor = UInt32(Utf16.utf8Offset(in: text, utf16: caretUtf16))
        let q = CompletionQuery(
            queryId: request.queryId,
            sessionId: request.document?.sessionId ?? 0,
            prefix: "",
            mode: .bufferLocal,
            context: .unknown,
            cursorByte: cursor,
            replaceStartByte: cursor,
            currentCrate: nil,
            currentModule: nil,
            kindFilter: nil,
            limit: 50
        )
        RideEngineClient.shared.withEngine { engine in
            engine.queryCompletions(q: q)
        } then: { resp in
            done(resp, caretUtf16)
        }
    }
}
