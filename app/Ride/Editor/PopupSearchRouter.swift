import AppKit

protocol SearchablePopup: AnyObject {
    var isVisible: Bool { get }
    var search: PopupSearch { get }
    var hasSearchSelection: Bool { get }
    func changeSearch(_ change: (inout PopupSearch) -> Void)
}

enum PopupSearchRouter {
    private static var completion: CompletionSession { .shared }
    private static var sheet: CheatSheetController { .shared }
    private static var popups: [SearchablePopup] { [sheet, completion] }

    static var active: SearchablePopup? {
        popups.first { $0.isVisible && $0.search.isActive }
    }

    private static var toggleTarget: SearchablePopup? {
        if let active {
            return active
        }
        if sheet.isVisible, !completion.isVisible || sheet.focused {
            return sheet
        }
        return completion.isVisible ? completion : nil
    }

    static func key(_ event: NSEvent) -> Bool {
        if PopupSearchKeys.isToggle(event), let target = toggleTarget {
            target.search.isActive ? target.changeSearch { $0.end() } : begin(target)
            return true
        }
        guard let active else {
            return false
        }
        switch event.keyCode {
        case 53:
            active.changeSearch { $0.end() }
            return true
        case 51:
            active.changeSearch { $0.deleteBackward() }
            return true
        case 36, 76, 48:
            return !active.hasSearchSelection
        default:
            guard let text = PopupSearchKeys.typed(event) else {
                return false
            }
            active.changeSearch { $0.type(text) }
            return true
        }
    }

    static func claims(_ event: NSEvent) -> Bool {
        if PopupSearchKeys.isToggle(event) {
            return toggleTarget != nil
        }
        return active != nil && PopupSearchKeys.typed(event) != nil
    }

    static func begin(_ target: SearchablePopup) {
        for other in popups where other !== target && other.search.isActive {
            other.changeSearch { $0.end() }
        }
        if target === sheet {
            sheet.focus()
        } else {
            sheet.blur()
        }
        target.changeSearch { $0.begin() }
    }
}

enum PopupSearchKeys {
    static func isToggle(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command && event.charactersIgnoringModifiers == "f"
    }

    static func typed(_ event: NSEvent) -> String? {
        guard event.modifierFlags.isDisjoint(with: [.command, .control]), let characters = event.characters else {
            return nil
        }
        return PopupSearch.typed(characters)
    }
}
