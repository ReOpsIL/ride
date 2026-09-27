import Foundation

enum Overlay: Equatable {
    case quickOpen
    case recentFiles
    case goToLine
    case symbolInFile
    case symbolInProject
    case projectFind

    static func toggled(_ current: Overlay?, pressing pressed: Overlay) -> Overlay? {
        current == pressed ? nil : pressed
    }

    static func setting(_ current: Overlay?, _ overlay: Overlay, shown: Bool) -> Overlay? {
        if shown {
            return overlay
        }
        return current == overlay ? nil : current
    }
}
