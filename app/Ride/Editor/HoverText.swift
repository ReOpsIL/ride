import Foundation

struct HoverContent {
    let signature: String
    let doc: String
    let origin: String
}

enum HoverText {
    static func content(_ resp: DefinitionResponse) -> HoverContent? {
        guard let hit = resp.hits.first(where: { !$0.signature.isEmpty || CompletionRowStyle.hasDoc($0) }) else {
            return nil
        }
        let origin = hit.crateName.isEmpty ? hit.path : "\(hit.path) · \(hit.crateName)"
        return HoverContent(signature: hit.signature, doc: CompletionRowStyle.docText(hit), origin: origin)
    }
}
