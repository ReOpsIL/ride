import Foundation

enum MarkdownPage {
    static func matches(_ url: URL?) -> Bool {
        switch url?.pathExtension.lowercased() {
        case "md", "markdown":
            return true
        default:
            return false
        }
    }
}
