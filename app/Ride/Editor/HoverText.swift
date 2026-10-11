import Foundation

struct HoverContent {
    let signature: String
    let doc: String
    let origin: String
}

enum HoverText {
    static func content(_ resp: DefinitionResponse) -> HoverContent? {
        guard let hit = resp.hits.first(where: { !$0.signature.isEmpty || CompletionRowStyle.hasDoc(.engine($0)) }) else {
            return nil
        }
        let origin = hit.crateName.isEmpty ? hit.path : "\(hit.path) · \(hit.crateName)"
        return HoverContent(signature: hit.signature, doc: CompletionRowStyle.docText(.engine(hit)), origin: origin)
    }

    static func documented(_ card: HoverContent?, rendered: QuickDoc?) -> HoverContent? {
        let full = rendered.map { HoverDocText.plain($0.html) } ?? ""
        let signature = card?.signature ?? rendered?.signature ?? ""
        let doc = full.isEmpty ? (card?.doc ?? "") : full
        let origin = card?.origin ?? rendered.map { DocPage.origin(path: $0.originPath, line: $0.originLine) } ?? ""
        guard !signature.isEmpty || !doc.isEmpty else {
            return nil
        }
        return HoverContent(signature: signature, doc: doc, origin: origin)
    }
}
