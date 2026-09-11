import Foundation

struct FileHit: Equatable {
    let file: URL
    let text: String
    let ranges: [NSRange]
}

struct FileEdit: Equatable {
    let file: URL
    let text: String
}

enum ProjectReplace {
    static func edits(
        hits: [FileHit],
        query: String,
        replacement: String,
        options: FindOptions = .defaults
    ) -> [FileEdit] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty, let expression = FindMatcher.expression(needle, options: options) else {
            return []
        }
        let template = FindMatcher.replacement(replacement, options: options)
        return hits.compactMap { hit in
            rewrite(hit, expression: expression, template: template)
        }
    }

    private static func rewrite(
        _ hit: FileHit,
        expression: NSRegularExpression,
        template: String
    ) -> FileEdit? {
        let ns = hit.text as NSString
        let next = expression.stringByReplacingMatches(
            in: hit.text,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: template
        )
        guard next != hit.text else {
            return nil
        }
        return FileEdit(file: hit.file, text: next)
    }
}
