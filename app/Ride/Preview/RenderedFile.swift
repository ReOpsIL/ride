import Foundation

enum RenderedFile {
    static func matches(_ url: URL?) -> Bool {
        HtmlPage.matches(url) || MarkdownPage.matches(url) || SvgPage.matches(url)
    }
}
