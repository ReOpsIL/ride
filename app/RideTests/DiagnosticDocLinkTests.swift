import XCTest

final class DiagnosticDocLinkTests: XCTestCase {
    func testClippyLink() {
        XCTAssertEqual(
            DiagnosticDocLink.url(for: "clippy::needless_return")?.absoluteString,
            "https://rust-lang.github.io/rust-clippy/master/index.html#needless_return"
        )
    }

    func testRustErrorLink() {
        XCTAssertEqual(
            DiagnosticDocLink.url(for: "E0308")?.absoluteString,
            "https://doc.rust-lang.org/error_codes/E0308.html"
        )
    }

    func testClangWarningLink() {
        XCTAssertEqual(
            DiagnosticDocLink.url(for: "-Wunused-variable")?.absoluteString,
            "https://clang.llvm.org/docs/DiagnosticsReference.html#wunused-variable"
        )
    }

    func testClangTidyCheckLink() {
        XCTAssertEqual(
            DiagnosticDocLink.url(for: "modernize-use-nullptr")?.absoluteString,
            "https://clang.llvm.org/extra/clang-tidy/checks/modernize/use-nullptr.html"
        )
    }

    func testUnlinkableCodes() {
        XCTAssertNil(DiagnosticDocLink.url(for: "unused_variables"))
        XCTAssertNil(DiagnosticDocLink.url(for: ""))
    }
}
