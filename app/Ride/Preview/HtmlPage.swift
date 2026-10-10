import Foundation

enum HtmlNav {
    case load
    case link
    case form
}

enum HtmlNavDecision: Equatable {
    case allow
    case open(URL)
    case block
}

enum HtmlPage {
    static let scheme = "ride-html"
    static let host = "local"

    static func matches(_ url: URL?) -> Bool {
        switch url?.pathExtension.lowercased() {
        case "html", "htm":
            return true
        default:
            return false
        }
    }

    static func url(named name: String) -> URL? {
        guard !name.isEmpty, !name.contains("/") else {
            return nil
        }
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = host
        parts.path = "/" + name
        return parts.url
    }

    static func decide(_ kind: HtmlNav, _ url: URL?) -> HtmlNavDecision {
        guard let url, let scheme = url.scheme?.lowercased(), kind != .form else {
            return .block
        }
        if scheme == Self.scheme, url.host == host {
            return .allow
        }
        if kind == .link, scheme == "http" || scheme == "https" {
            return .open(url)
        }
        return .block
    }
}
