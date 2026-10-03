import AppKit

final class CompletionSearchScratch {
    var text = ""
    var term = ""
    var target = ""
}

extension SelfTestSteps {
    static func completionSearchSteps(e: SelfTestEditor) -> [SelfTestStep] {
        let s = CompletionSearchScratch()
        return [searchOpens(e: e, s: s), searchMatchesBeyondNames(e: e, s: s), searchEscapeKeepsPopup(e: e)]
    }

    private static var session: CompletionSession { CompletionSession.shared }

    private static func searchOpens(e: SelfTestEditor, s: CompletionSearchScratch) -> SelfTestStep {
        SelfTestStep(name: "completion search opens", until: { session.search.isActive }, timeout: 3, run: {
            s.text = e.text
            SelfTestKeys.post("⌘F", window: SelfTestKeys.mainWindow)
        }, check: {
            e.expect(session.isVisible && session.search.isActive && e.text == s.text, "visible \(session.isVisible) active \(session.search.isActive)")
        })
    }

    private static func searchMatchesBeyondNames(e: SelfTestEditor, s: CompletionSearchScratch) -> SelfTestStep {
        SelfTestStep(name: "completion search matches beyond names", until: { session.search.query == s.term }, timeout: 3, run: {
            (s.target, s.term) = textTerm(in: session.popup.hits) ?? ("", "")
            for character in s.term {
                SelfTestKeys.post(String(character), window: SelfTestKeys.mainWindow)
            }
        }, check: {
            let hits = session.popup.hits
            let matching = hits.allSatisfy { $0.searchFields.joined(separator: " ").lowercased().contains(s.term) }
            let found = hits.contains { $0.name == s.target }
            return e.expect(!s.term.isEmpty && matching && found && e.text == s.text, "term '\(s.term)' hits \(hits.count) target \(found)")
        })
    }

    private static func searchEscapeKeepsPopup(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "completion search escape keeps popup", until: { !session.search.isActive }, timeout: 3, run: {
            SelfTestKeys.post("esc", window: SelfTestKeys.mainWindow)
        }, check: {
            e.expect(session.isVisible && session.search.query.isEmpty, "visible \(session.isVisible) query '\(session.search.query)'")
        })
    }

    private static func textTerm(in hits: [CompletionItem]) -> (String, String)? {
        for item in hits {
            let text = item.searchFields.dropFirst().joined(separator: " ").lowercased()
            let words = text.split { !$0.isLetter || !$0.isASCII }.map(String.init)
            if let word = words.first(where: { $0.count >= 3 && !item.name.lowercased().contains($0) }) {
                return (item.name, word)
            }
        }
        return nil
    }
}
