import XCTest

final class TreeModelTests: XCTestCase {
    func testDeleteRunsTrash() {
        XCTAssertEqual(TreeModel.action(keyCode: TreeModel.delete), .trash)
        XCTAssertEqual(TreeModel.action(keyCode: TreeModel.forwardDelete), .trash)
    }

    func testReturnRunsRename() {
        XCTAssertEqual(TreeModel.action(keyCode: TreeModel.return), .rename)
        XCTAssertEqual(TreeModel.action(keyCode: TreeModel.keypadEnter), .rename)
    }

    func testOtherKeysDoNothing() {
        XCTAssertNil(TreeModel.action(keyCode: 0))
        XCTAssertNil(TreeModel.action(keyCode: 49))
        XCTAssertNil(TreeModel.action(keyCode: 53))
    }
}
