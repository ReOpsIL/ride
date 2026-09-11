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

struct ProjectReplaceResult: Equatable {
    let edits: [FileEdit]
    let skipped: [URL]
}

enum ProjectReplace {
    static func refresh(
        _ hits: [FileHit],
        query: String,
        options: FindOptions,
        text: (URL) -> String?
    ) -> [FileHit] {
        hits.map { hit in
            let current = text(hit.file) ?? ""
            return FileHit(
                file: hit.file,
                text: current,
                ranges: FindMatcher.matches(in: current, query: query, options: options)
            )
        }
    }

    static func edits(
        hits: [FileHit],
        query: String,
        replacement: String,
        options: FindOptions = .defaults
    ) -> ProjectReplaceResult {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty, let expression = FindMatcher.expression(needle, options: options) else {
            return ProjectReplaceResult(edits: [], skipped: [])
        }
        let template = FindMatcher.replacement(replacement, options: options)
        var edits: [FileEdit] = []
        var skipped: [URL] = []
        for hit in hits {
            if FindMatcher.matches(in: hit.text, query: needle, options: options).isEmpty {
                skipped.append(hit.file)
                continue
            }
            if let edit = rewrite(hit, expression: expression, template: template) {
                edits.append(edit)
            }
        }
        return ProjectReplaceResult(edits: edits, skipped: skipped)
    }

    static func summary(matches: Int, files: Int, skipped: [URL], failed: [URL]) -> String? {
        var parts: [String] = []
        if files > 0 {
            parts.append(
                "Replaced \(Plural.count(matches, "match", plural: "matches")) in \(Plural.count(files, "file"))"
            )
        }
        if !skipped.isEmpty {
            parts.append("Skipped \(names(skipped))")
        }
        if !failed.isEmpty {
            parts.append("Failed \(names(failed))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    private static func names(_ urls: [URL]) -> String {
        urls.map(\.lastPathComponent).joined(separator: ", ")
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
