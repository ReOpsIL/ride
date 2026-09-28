import AppKit

struct OracleWait {
    let sessionId: UInt64
    let caret: Int
    let length: Int
    weak var document: BufferDocument?
    weak var view: RideTextView?
    weak var state: AppState?
}

extension CompletionSession {
    func awaitOracle(document: BufferDocument, view: RideTextView, state: AppState) {
        oracleWait = document.sessionId.map {
            OracleWait(
                sessionId: $0,
                caret: view.selectedRange().location,
                length: (view.string as NSString).length,
                document: document,
                view: view,
                state: state
            )
        }
    }

    func oracleAnswered(sessionId: UInt64) {
        guard let wait = oracleWait, wait.sessionId == sessionId,
              let document = wait.document, let view = wait.view, let state = wait.state,
              view.window?.firstResponder === view,
              view.selectedRange().length == 0,
              showing(in: view) || unchanged(view, since: wait)
        else {
            return
        }
        schedule(document: document, view: view, state: state)
    }

    private func showing(in view: RideTextView) -> Bool {
        popup.isVisible && popup.textView === view
    }

    private func unchanged(_ view: RideTextView, since wait: OracleWait) -> Bool {
        view.selectedRange().location == wait.caret && (view.string as NSString).length == wait.length
    }

    func dismiss() {
        oracleWait = nil
        hide()
    }
}
