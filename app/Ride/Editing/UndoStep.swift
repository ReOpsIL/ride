import Foundation

enum UndoStep {
    private static var depth = 0

    static func manager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    static func add(_ manager: UndoManager, _ register: () -> Void) {
        guard manager.groupingLevel == 0 else {
            register()
            return
        }
        manager.beginUndoGrouping()
        register()
        manager.endUndoGrouping()
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
