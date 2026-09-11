import XCTest

final class UpdateControllerTests: XCTestCase {
    func testPlaceholderKeyIsNotConfigured() {
        XCTAssertFalse(UpdateController.isConfigured(publicKey: UpdateController.placeholderPublicKey))
    }

    func testEmptyKeyIsNotConfigured() {
        XCTAssertFalse(UpdateController.isConfigured(publicKey: ""))
    }

    func testOtherKeyIsConfigured() {
        XCTAssertTrue(UpdateController.isConfigured(publicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB="))
    }
}
