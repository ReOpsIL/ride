import XCTest

final class CargoWatchTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/tmp/proj")

    func testManifestPaths() {
        XCTAssertTrue(CargoWatch.isManifest("/tmp/proj/Cargo.toml", root: root))
        XCTAssertTrue(CargoWatch.isManifest("/tmp/proj/crates/a/Cargo.lock", root: root))
        XCTAssertFalse(CargoWatch.isManifest("/tmp/proj/target/debug/build/x/Cargo.toml", root: root))
        XCTAssertFalse(CargoWatch.isManifest("/tmp/proj/src/main.rs", root: root))
        XCTAssertTrue(CargoWatch.touchesManifest(["/tmp/proj/src/a.rs", "/tmp/proj/Cargo.lock"], root: root))
    }

    func testCargoManifestField() {
        let text = "[package]\nname = \"demo\"\nedition = \"2021\"\n"
        XCTAssertEqual(CargoManifest.field("name", in: text), "demo")
        XCTAssertEqual(CargoManifest.field("edition", in: text), "2021")
        XCTAssertNil(CargoManifest.field("version", in: text))
    }
}
