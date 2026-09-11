import XCTest

final class ManifestWatchTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/tmp/proj")

    func testCargoManifestPaths() {
        XCTAssertTrue(ManifestWatch.isCargoManifest("/tmp/proj/Cargo.toml", root: root))
        XCTAssertTrue(ManifestWatch.isCargoManifest("/tmp/proj/crates/a/Cargo.lock", root: root))
        XCTAssertFalse(ManifestWatch.isCargoManifest("/tmp/proj/target/debug/build/x/Cargo.toml", root: root))
        XCTAssertFalse(ManifestWatch.isCargoManifest("/tmp/proj/src/main.rs", root: root))
        XCTAssertTrue(ManifestWatch.change(["/tmp/proj/src/a.rs", "/tmp/proj/Cargo.lock"], root: root).reindexCargo)
    }

    func testCompileDatabasePaths() {
        XCTAssertTrue(ManifestWatch.isManifest("/tmp/proj/compile_commands.json", root: root))
        XCTAssertTrue(ManifestWatch.isManifest("/tmp/proj/build/compile_commands.json", root: root))
        XCTAssertFalse(ManifestWatch.isManifest("/tmp/proj/build/Debug/compile_commands.json", root: root))
        XCTAssertFalse(ManifestWatch.isManifest("/tmp/proj/target/CMakeLists.txt", root: root))
        XCTAssertTrue(ManifestWatch.isManifest("/tmp/proj/CMakeLists.txt", root: root))
    }

    func testChangeSeparatesProjectFromIndex() {
        let change = ManifestWatch.change(["/tmp/proj/build/compile_commands.json"], root: root)
        XCTAssertTrue(change.reloadProject)
        XCTAssertFalse(change.reindexCargo)
        let none = ManifestWatch.change(["/tmp/proj/build/Debug/compile_commands.json"], root: root)
        XCTAssertEqual(none, ManifestChange(reloadProject: false, reindexCargo: false))
    }

    func testCargoManifestField() {
        let text = "[package]\nname = \"demo\"\nedition = \"2021\"\n"
        XCTAssertEqual(CargoManifest.field("name", in: text), "demo")
        XCTAssertEqual(CargoManifest.field("edition", in: text), "2021")
        XCTAssertNil(CargoManifest.field("version", in: text))
    }
}
