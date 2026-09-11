import XCTest

final class BufferLanguageTests: XCTestCase {
    func testLanguageFromExtension() {
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/main.rs")), .rust)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/main.c")), .c)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/main.h")), .c)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/main.CPP")), .cpp)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/main.hpp")), .cpp)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/notes.md")), .markdown)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/Cargo.toml")), .toml)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/Makefile")), .make)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/GNUmakefile")), .make)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/rules.mk")), .make)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/CMakeLists.txt")), .cmake)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/cmake/Warnings.cmake")), .cmake)
        XCTAssertEqual(BufferLanguage.of(URL(fileURLWithPath: "/a/Cargo.lock")), .plain)
        XCTAssertEqual(BufferLanguage.of(nil), .rust)
    }

    func testFileExtensionRoundTrips() {
        for language in [BufferLanguage.rust, .c, .cpp, .toml, .make, .cmake, .markdown] {
            let url = URL(fileURLWithPath: "/a/x." + language.fileExtension)
            XCTAssertEqual(BufferLanguage.of(url), language)
        }
    }

    func testClangLanguages() {
        XCTAssertTrue(BufferLanguage.c.usesClang)
        XCTAssertTrue(BufferLanguage.cpp.usesClang)
        XCTAssertFalse(BufferLanguage.rust.usesClang)
        XCTAssertFalse(BufferLanguage.markdown.usesClang)
        XCTAssertFalse(BufferLanguage.cmake.usesClang)
    }

    func testSniffExtensionlessCpp() {
        let vector = URL(fileURLWithPath: "/opt/sysroot/include/c++/v1/vector")
        XCTAssertEqual(BufferLanguage.sniff(url: vector, text: "// empty\n", isSystem: true), .cpp)
        XCTAssertEqual(BufferLanguage.sniff(url: vector, text: "// empty\n", isSystem: false), .plain)
        let local = URL(fileURLWithPath: "/proj/samples/buffer")
        XCTAssertEqual(BufferLanguage.sniff(url: local, text: "class vector {\n};\n", isSystem: false), .cpp)
        XCTAssertEqual(BufferLanguage.sniff(url: local, text: "hello world\n", isSystem: false), .plain)
        XCTAssertEqual(BufferLanguage.sniff(url: URL(fileURLWithPath: "/a/main.rs"), text: "class X {};\n", isSystem: false), .rust)
    }
}
