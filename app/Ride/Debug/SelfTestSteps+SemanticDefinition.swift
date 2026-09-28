import AppKit

final class SemanticDefinitionScratch {
    var start = 0
    var typed = ""
    var asked = Date.distantPast
    var excerpts: [DefinitionExcerpt] = []
}

extension SelfTestSteps {
    static func semanticDefinition(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let s = SemanticDefinitionScratch()
        let typed = "\n    let _n = \"a.b\".split('.').count();"
        return SelfTestStep(name: "semantic definition", until: {
            if docsHTML().contains("Consumes the iterator") {
                return true
            }
            if Date().timeIntervalSince(s.asked) > 1 {
                s.asked = Date()
                placeCaret(e, on: ".count()")
                e.view.map { $0.setSelectedRange(NSRange(location: $0.selectedRange().location + 1, length: 0)) }
                state.showQuickDocumentation()
            }
            return false
        }, timeout: 60, run: {
            typeLine(e, s, after: "fn main() {", typed)
        }, check: {
            let html = docsHTML()
            EditorPanes.shared.focused?.closeDocs()
            removeLine(e, s)
            return e.expect(html.contains("Consumes the iterator"), "doc \(html.prefix(160))")
        })
    }

    static func semanticCppDefinition(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let s = SemanticDefinitionScratch()
        let typed = "\n    auto it = rects.begin();\n    auto _p = it->perimeter();"
        return SelfTestStep(name: "semantic cpp definition", until: {
            if onlyRect(s.excerpts) {
                return true
            }
            if Date().timeIntervalSince(s.asked) > 1, let document = state.focusedEditor?.document, let view = e.view {
                s.asked = Date()
                let at = (view.string as NSString).range(of: "->perimeter").location + 2
                let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: at))
                SessionService.shared.quickDefinition(document: document, cursorByte: byte) { s.excerpts = $0 }
            }
            return false
        }, timeout: 60, run: {
            typeLine(e, s, after: "std::vector<geo::Rect> rects = {rect, square};", typed)
        }, check: {
            let paths = s.excerpts.map { ($0.path as NSString).lastPathComponent }
            removeLine(e, s)
            return e.expect(onlyRect(s.excerpts), "excerpts \(paths) \(s.excerpts.map { $0.text.prefix(40) })")
        })
    }

    private static func onlyRect(_ excerpts: [DefinitionExcerpt]) -> Bool {
        !excerpts.isEmpty
            && excerpts.contains { $0.path.hasSuffix("shapes.cpp") && $0.text.contains("Rect::perimeter") }
            && !excerpts.contains { $0.text.contains("Circle::perimeter") }
    }

    private static func docsHTML() -> String {
        EditorPanes.shared.focused?.docs.html ?? ""
    }

    private static func typeLine(_ e: SelfTestEditor, _ s: SemanticDefinitionScratch, after anchor: String, _ text: String) {
        e.activate()
        e.place(on: anchor, atEnd: true)
        s.start = e.view?.selectedRange().location ?? 0
        s.typed = text
        e.type(text)
        CompletionSession.shared.dismiss()
    }

    private static func removeLine(_ e: SelfTestEditor, _ s: SemanticDefinitionScratch) {
        CompletionSession.shared.dismiss()
        let range = NSRange(location: s.start, length: (s.typed as NSString).length)
        e.view?.insertText("", replacementRange: range)
    }
}

extension SelfTestSteps {
    static func menuTypeInfo(e: SelfTestEditor) -> SelfTestStep {
        let s = SemanticDefinitionScratch()
        let typed = "\n    let _parts = \"a.b\".split('.').collect::<Vec<_>>();"
        let shown = { (EditorPanes.shared.focused?.docs.html ?? "").contains("Vec&lt;&amp;str&gt;") }
        return SelfTestStep(name: "menu type info", until: {
            if shown() {
                return true
            }
            if Date().timeIntervalSince(s.asked) > 1 {
                s.asked = Date()
                placeCaret(e, on: "_parts")
                SelfTestMenu.perform("Code › Type Info")
            }
            return false
        }, timeout: 60, run: {
            e.activate()
            e.place(on: "fn main() {", atEnd: true)
            s.start = e.view?.selectedRange().location ?? 0
            s.typed = typed
            e.type(typed)
            CompletionSession.shared.dismiss()
        }, check: {
            let html = EditorPanes.shared.focused?.docs.html ?? ""
            EditorPanes.shared.focused?.closeDocs()
            CompletionSession.shared.dismiss()
            e.view?.insertText("", replacementRange: NSRange(location: s.start, length: (s.typed as NSString).length))
            return e.expect(html.contains("Vec&lt;&amp;str&gt;"), "type info \(html.suffix(240))")
        })
    }
}
