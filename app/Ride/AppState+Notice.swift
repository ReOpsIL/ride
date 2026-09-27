import Foundation

extension AppState {
    func showNotice(
        _ text: String,
        seconds: Double = 6,
        action: (title: String, run: () -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let replaced = noticeQueue.push(Notice(text: text, seconds: seconds, action: action, onDismiss: onDismiss))
        present(noticeQueue.current)
        replaced?.onDismiss?()
    }

    func dismissNotice() {
        let run = noticeDismiss
        clearNotice()
        run?()
    }

    func clearNotice() {
        present(noticeQueue.advance())
    }

    private func present(_ next: Notice?) {
        noticeWork?.cancel()
        noticeWork = nil
        notice = next?.text
        noticeAction = next?.action
        noticeDismiss = next?.onDismiss
        guard let next else {
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.clearNotice()
        }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + next.seconds, execute: work)
    }
}
