import Foundation

enum HtmlPolicy {
    static let content = [
        "default-src 'none'",
        "script-src 'self' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data:",
        "font-src 'self' data:",
        "media-src 'self'",
        "connect-src 'self'",
        "object-src 'none'",
        "base-uri 'none'",
        "form-action 'none'",
        "frame-src 'none'",
    ].joined(separator: "; ")

    static func stamp(_ html: String) -> String {
        let meta = "<meta http-equiv=\"Content-Security-Policy\" content=\"\(content)\">"
        if let insert = headEnd(html) {
            var copy = html
            copy.insert(contentsOf: meta, at: insert)
            return copy
        }
        return "<head>\(meta)</head>" + html
    }

    private static func headEnd(_ html: String) -> String.Index? {
        var search = html.startIndex
        while search < html.endIndex,
              let range = html.range(of: "<head", options: .caseInsensitive, range: search..<html.endIndex) {
            let next = range.upperBound
            if next < html.endIndex, headTag(html[next]), let end = html[next...].firstIndex(of: ">") {
                return html.index(after: end)
            }
            search = next
        }
        return nil
    }

    private static func headTag(_ scalar: Character) -> Bool {
        scalar == ">" || scalar == "/" || scalar.isWhitespace
    }
}
