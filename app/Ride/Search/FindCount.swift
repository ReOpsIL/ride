import Foundation

enum FindCount {
    static func label(current: NSRange?, in text: String, query: String, options: FindOptions = .defaults) -> String? {
        if query.isEmpty {
            return nil
        }
        let all = FindMatcher.matches(in: text, query: query, options: options)
        if all.isEmpty {
            return "No results"
        }
        if let current, let index = all.firstIndex(where: { $0.location == current.location }) {
            return "\(index + 1) of \(all.count)"
        }
        return "\(all.count)"
    }
}
