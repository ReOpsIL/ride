enum TreeAction: Equatable {
    case rename
    case trash
}

enum TreeModel {
    static let delete: UInt16 = 51
    static let forwardDelete: UInt16 = 117
    static let `return`: UInt16 = 36
    static let keypadEnter: UInt16 = 76

    static func action(keyCode: UInt16, modifiers: KeyModifiers = []) -> TreeAction? {
        switch keyCode {
        case delete, forwardDelete:
            return modifiers.isSubset(of: .command) ? .trash : nil
        case `return`, keypadEnter:
            return modifiers.isEmpty ? .rename : nil
        default:
            return nil
        }
    }
}
