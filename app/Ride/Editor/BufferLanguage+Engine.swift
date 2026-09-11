import Foundation

extension BufferLanguage {
    static func sniff(url: URL?, text: String) -> BufferLanguage {
        sniff(url: url, text: text, isSystem: url.map(isSystemPath) ?? false)
    }

    static func isReadOnly(_ url: URL) -> Bool {
        isSystemPath(url)
    }

    static func isSystemPath(_ url: URL) -> Bool {
        RideEngineClient.shared.engine?.isSystemPath(path: url.standardizedFileURL.path) ?? false
    }
}
