import AppKit

final class HierarchyFollower {
    static let shared = HierarchyFollower()
    static let delay: TimeInterval = 0.35
    private var pending: DispatchWorkItem?
    private var anchor: String?

    func anchored(_ key: String?) {
        pending?.cancel()
        pending = nil
        anchor = key
    }

    func caretMoved(document: BufferDocument, view: RideTextView, state: AppState) {
        guard state.showHierarchy, state.hierarchy.finished || state.hierarchy.running else {
            return
        }
        let key = Self.key(document: document, view: view)
        guard key != anchor else {
            return
        }
        pending?.cancel()
        let work = DispatchWorkItem { [weak state] in
            guard let state, state.showHierarchy else {
                return
            }
            state.followHierarchy()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    static func key(document: BufferDocument, view: RideTextView) -> String {
        let text = view.string as NSString
        if let name = IdentifierRange.at(text, index: view.selectedRange().location) {
            return "\(document.id)|name|\(name.location)|\(text.substring(with: name))"
        }
        let byte = document.caretByte
        let item = document.outline.last { $0.startByte <= byte && byte < $0.endByte }
        return "\(document.id)|item|\(item.map { String($0.startByte) } ?? "none")"
    }
}
