import Foundation

struct OpenRequest: Equatable {
    let path: String
    let line: Int?
    let column: Int?
}

private struct OpenPosition {
    let value: Int?

    init?(_ raw: String?) {
        guard let raw else {
            value = nil
            return
        }
        guard let number = Int(raw), number > 0 else {
            return nil
        }
        value = number
    }
}

enum OpenURLParser {
    static func request(from url: URL) -> OpenRequest? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "ride",
              components.host?.lowercased() == "open",
              let items = components.queryItems,
              let path = items.first(where: { $0.name == "path" })?.value,
              !path.isEmpty,
              let line = OpenPosition(value(of: "line", in: items)),
              let column = OpenPosition(value(of: "column", in: items))
        else {
            return nil
        }
        return OpenRequest(path: path, line: line.value, column: column.value)
    }

    private static func value(of name: String, in items: [URLQueryItem]) -> String? {
        items.first { $0.name == name }?.value
    }
}
