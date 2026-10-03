import AppKit

extension CheatSheetController: SearchablePopup {
    var hasSearchSelection: Bool {
        popup.selectedEntry != nil
    }

    func changeSearch(_ change: (inout PopupSearch) -> Void) {
        change(&search)
        guard let view else {
            return
        }
        present(in: view)
    }
}
