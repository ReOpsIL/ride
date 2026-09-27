import XCTest

final class ShortcutsTableTests: XCTestCase {
    func testEveryBindingParsesAndIsWrittenCanonically() {
        for binding in Shortcuts.bindings {
            guard let combo = binding.combo else {
                XCTFail("unparsable \(binding.keys)")
                continue
            }
            XCTAssertEqual(combo.description, binding.keys, binding.path ?? binding.keys)
        }
    }

    func testNoTwoBindingsShareACombo() {
        let combos = Shortcuts.bindings.compactMap(\.combo)
        let repeated = Dictionary(grouping: combos, by: { $0 }).filter { $0.value.count > 1 }.keys
        XCTAssertEqual(repeated.map(\.description), [])
    }

    func testEditorScopeCoversTheStandardTextKeys() {
        let taken = ["⌃W", "⌃H", "⌘⌫", "⇧⌘↑", "⇧⌘↓", "⌥↑", "⌥↓", "⌥⇧↑", "⌥⇧↓", "⌃Space", "⇧↩", "⌃J", "⌃M"]
        for keys in taken {
            XCTAssertTrue(Shortcuts.editorScoped.contains(KeyCombo(glyphs: keys)!), keys)
        }
        XCTAssertFalse(Shortcuts.editorScoped.contains(KeyCombo(glyphs: "⌘S")!))
    }

    func testHelpTextComesFromTheTable() {
        XCTAssertEqual(Shortcuts.help("Problems", "View › Problems"), "Problems (⌘6)")
        XCTAssertEqual(Shortcuts.help("Nothing", "View › Missing"), "Nothing")
    }
}
