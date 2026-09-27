import XCTest

final class ShortcutAuditTests: XCTestCase {
    private func item(_ path: String, _ keys: String) -> MenuShortcut {
        MenuShortcut(path: path, combo: KeyCombo(glyphs: keys)!)
    }

    func testCleanMenuHasNoProblems() {
        let audit = ShortcutAudit(menu: [item("Edit › Select Word", "⌃W")], bindings: [.menu("Edit › Select Word", "⌃W", .editor)], exempt: [:])
        XCTAssertEqual(audit.problems, [])
    }

    func testDuplicateKeysAcrossItemsAreReported() {
        let audit = ShortcutAudit(menu: [item("A › One", "⌘E"), item("B › Two", "⌘E")], bindings: [], exempt: ["A › One": "x", "B › Two": "x"])
        XCTAssertEqual(audit.duplicates, ["⌘E on A › One and B › Two"])
    }

    func testPanelKeysThatDisagreeWithTheMenuAreReported() {
        let audit = ShortcutAudit(menu: [item("View › Problems", "⌘6")], bindings: [.menu("View › Problems", "⇧⌘M"), .menu("View › Gone", "⌘9")], exempt: [:])
        XCTAssertEqual(audit.mismatched.count, 2)
        XCTAssertEqual(audit.unlisted, ["⌘6 View › Problems missing from the panel"])
    }

    func testExemptItemsNeedNoPanelEntry() {
        let audit = ShortcutAudit(menu: [item("Edit › Undo", "⌘Z")], bindings: [], exempt: ShortcutAudit.systemItems)
        XCTAssertEqual(audit.problems, [])
    }
}
