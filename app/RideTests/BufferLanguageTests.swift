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
}
