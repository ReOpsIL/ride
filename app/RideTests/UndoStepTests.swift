import XCTest

final class UndoStepTests: XCTestCase {
    private final class Box {
        var value = 0
    }

    private func manager() -> UndoManager {
        UndoStep.manager()
    }

    private func register(_ manager: UndoManager, _ box: Box, _ value: Int) {
        manager.registerUndo(withTarget: box) { target in
            target.value = value
        }
    }

    func testPerformClosesEveryGroupItOpens() {
        let manager = manager()
        let box = Box()
        UndoStep.perform(manager) { register(manager, box, 1) }
        XCTAssertEqual(manager.groupingLevel, 0)
        XCTAssertTrue(manager.canUndo)
    }

    func testPerformClosesGroupsLeftOpenByTheBody() {
        let manager = manager()
        let box = Box()
        UndoStep.perform(manager) {
            manager.beginUndoGrouping()
            register(manager, box, 1)
        }
        XCTAssertEqual(manager.groupingLevel, 0)
    }

    func testEachPerformIsOneUndoStep() {
        let manager = manager()
        let box = Box()
        UndoStep.perform(manager) { register(manager, box, 1) }
        UndoStep.perform(manager) { register(manager, box, 2) }
        manager.undo()
        XCTAssertEqual(box.value, 2)
        manager.undo()
        XCTAssertEqual(box.value, 1)
        XCTAssertFalse(manager.canUndo)
    }

    func testPerformSeparatesEditsLeftInAnOpenGroup() {
        let manager = manager()
        let box = Box()
        manager.beginUndoGrouping()
        register(manager, box, 1)
        UndoStep.perform(manager) { register(manager, box, 2) }
        manager.undo()
        XCTAssertEqual(box.value, 2)
        XCTAssertTrue(manager.canUndo)
    }

    func testCloseKeepsTheRedoGroupWhileUndoing() {
        let manager = manager()
        let box = Box()
        UndoStep.perform(manager) {
            manager.registerUndo(withTarget: box) { target in
                manager.registerUndo(withTarget: target) { redone in
                    redone.value = 1
                }
                UndoStep.close(manager)
                target.value = 0
            }
        }
        manager.undo()
        XCTAssertEqual(box.value, 0)
        XCTAssertTrue(manager.canRedo)
        manager.redo()
        XCTAssertEqual(box.value, 1)
    }

    func testEachAddIsOneUndoStep() {
        let manager = manager()
        let box = Box()
        for value in 1...3 {
            UndoStep.add(manager) { register(manager, box, value) }
            XCTAssertEqual(manager.groupingLevel, 0)
        }
        manager.undo()
        XCTAssertEqual(box.value, 3)
        manager.undo()
        XCTAssertEqual(box.value, 2)
    }

    func testAddJoinsAnOpenGroup() {
        let manager = manager()
        let box = Box()
        manager.beginUndoGrouping()
        UndoStep.add(manager) { register(manager, box, 1) }
        XCTAssertEqual(manager.groupingLevel, 1)
        UndoStep.add(manager) { register(manager, box, 2) }
        manager.endUndoGrouping()
        manager.undo()
        XCTAssertEqual(box.value, 1)
        XCTAssertFalse(manager.canUndo)
    }

    func testAddWhileUndoingRegistersTheRedo() {
        let manager = manager()
        let box = Box()
        UndoStep.add(manager) {
            manager.registerUndo(withTarget: box) { target in
                UndoStep.add(manager) { self.register(manager, target, 1) }
                target.value = 0
            }
        }
        manager.undo()
        XCTAssertEqual(box.value, 0)
        XCTAssertEqual(manager.groupingLevel, 0)
        manager.redo()
        XCTAssertEqual(box.value, 1)
    }

    func testCloseIsSuppressedInsideAPerform() {
        let manager = manager()
        let box = Box()
        UndoStep.perform(manager) {
            register(manager, box, 1)
            UndoStep.close(manager)
            XCTAssertEqual(manager.groupingLevel, 1)
            register(manager, box, 2)
        }
        XCTAssertEqual(manager.groupingLevel, 0)
        manager.undo()
        XCTAssertEqual(box.value, 1)
        XCTAssertFalse(manager.canUndo)
    }

    func testManagerDoesNotGroupByEvent() {
        XCTAssertFalse(UndoStep.manager().groupsByEvent)
    }

    func testPerformRunsTheBodyWithoutAManager() {
        let box = Box()
        UndoStep.perform(nil) { box.value = 3 }
        XCTAssertEqual(box.value, 3)
    }
}
