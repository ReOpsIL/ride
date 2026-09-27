import XCTest

final class TreeKeysTests: XCTestCase {
    func testCommandDeleteTrashesLikeFinder() {
        XCTAssertEqual(TreeModel.action(keyCode: TreeModel.delete, modifiers: .command), .trash)
    }

    func testOtherModifiersDoNothing() {
        XCTAssertNil(TreeModel.action(keyCode: TreeModel.delete, modifiers: .option))
        XCTAssertNil(TreeModel.action(keyCode: TreeModel.return, modifiers: .option))
        XCTAssertNil(TreeModel.action(keyCode: TreeModel.return, modifiers: .command))
    }
}
