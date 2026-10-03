import AppKit

extension CompletionSession: SearchablePopup {
    var hasSearchSelection: Bool {
        popup.selectedHit != nil
    }

    func changeSearch(_ change: (inout PopupSearch) -> Void) {
        change(&search)
        guard let list, let view = popup.textView else {
            return
        }
        present(list, in: view, keepSelection: false)
    }
}
