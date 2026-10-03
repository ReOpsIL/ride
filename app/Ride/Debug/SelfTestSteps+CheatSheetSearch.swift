import AppKit

extension SelfTestSteps {
    static func cheatSheetSearchSteps(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let s = CompletionSearchScratch()
        return [sheetSearchOpens(e: e, s: s), sheetSearchFilters(e: e, s: s), sheetSearchEscape(stash: stash, e: e)]
    }

    private static var sheet: CheatSheetController { .shared }

    private static func sheetSearchOpens(e: SelfTestEditor, s: CompletionSearchScratch) -> SelfTestStep {
        SelfTestStep(name: "cheat sheet search opens", until: { sheet.search.isActive }, timeout: 3, run: {
            s.text = e.text
            SelfTestKeys.post("⌘F", window: SelfTestKeys.mainWindow)
        }, check: {
            e.expect(sheet.isVisible && sheet.focused && e.text == s.text, "visible \(sheet.isVisible) active \(sheet.search.isActive)")
        })
    }

    private static func sheetSearchFilters(e: SelfTestEditor, s: CompletionSearchScratch) -> SelfTestStep {
        SelfTestStep(name: "cheat sheet search filters", until: { !s.term.isEmpty && sheet.search.query == s.term }, timeout: 3, run: {
            (s.target, s.term) = sheetTerm(in: sheet.popup.rows.compactMap(\.entry)) ?? ("", "")
            for character in s.term {
                SelfTestKeys.post(String(character), window: SelfTestKeys.mainWindow)
            }
        }, check: {
            let entries = sheet.popup.rows.compactMap(\.entry)
            let found = entries.contains { $0.name == s.target }
            return e.expect(!s.term.isEmpty && found && e.text == s.text, "term '\(s.term)' entries \(entries.count) target \(found)")
        })
    }

    private static func sheetSearchEscape(stash: SelfTestStash, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "cheat sheet search escape keeps sheet", until: { !sheet.search.isActive }, timeout: 3, run: {
            SelfTestKeys.post("esc", window: SelfTestKeys.mainWindow)
        }, check: {
            stash.probe = sheet.popup.selectedEntry?.name ?? ""
            return e.expect(sheet.isVisible && sheet.pinned && sheet.search.query.isEmpty, "visible \(sheet.isVisible) pinned \(sheet.pinned)")
        })
    }

    private static func sheetTerm(in entries: [CheatItem]) -> (String, String)? {
        for entry in entries.dropLast() {
            let words = entry.doc.lowercased().split { !$0.isLetter || !$0.isASCII }.map(String.init)
            if let word = words.first(where: { $0.count >= 5 && !entry.name.lowercased().contains($0) }) {
                return (entry.name, word)
            }
        }
        return nil
    }
}
