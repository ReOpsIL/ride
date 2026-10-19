import Foundation

struct HoverContent {
    let signature: String
    let doc: String
    let origin: String
}

enum HoverText {
    static func shown(_ doc: QuickDoc) -> HoverContent? {
        let body = HoverDocText.plain(doc.html)
        let origin = DocPage.origin(path: doc.originPath, line: doc.originLine)
        guard !doc.signature.isEmpty || !body.isEmpty else {
            return nil
        }
        return HoverContent(signature: doc.signature, doc: body, origin: origin)
    }
}
