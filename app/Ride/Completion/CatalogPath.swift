import Foundation

enum CatalogPath {
    static func isCatalog(_ url: URL) -> Bool {
        let p = url.path
        return p.contains("/.cargo/registry/")
            || p.contains("/.cargo/git/")
            || p.contains("/lib/rustlib/src/rust/library/")
    }
}
