import Foundation

enum HoverText {
    static func render(_ resp: DefinitionResponse) -> String? {
        guard let hit = resp.hits.first(where: { !$0.signature.isEmpty || !$0.docFirstSentence.isEmpty }) else {
            return nil
        }
        var lines: [String] = []
        if !hit.signature.isEmpty {
            lines.append(hit.signature)
        }
        if !hit.docFirstSentence.isEmpty {
            lines.append(hit.docFirstSentence)
        }
        let origin = hit.crateName.isEmpty ? hit.path : "\(hit.path) @ \(hit.crateName)"
        lines.append(origin)
        return lines.joined(separator: "\n")
    }
}
