import Foundation

enum UndoStep {
    private static var depth = 0

    static func manager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    static func open(_ manager: UndoManager?) {
        guard let manager, !manager.isUndoing, !manager.isRedoing, manager.groupingLevel == 0 else {
            return
        }
        manager.beginUndoGrouping()
    }

    static func close(_ manager: UndoManager?) {
        guard depth == 0, let manager, !manager.isUndoing, !manager.isRedoing else {
            return
        }
        while manager.groupingLevel > 0 {
            manager.endUndoGrouping()
        }
    }

    static func perform(_ manager: UndoManager?, _ body: () -> Void) {
        close(manager)
        manager?.beginUndoGrouping()
        depth += 1
        body()
        depth -= 1
        close(manager)
    }
}
