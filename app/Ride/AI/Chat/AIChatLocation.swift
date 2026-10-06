import Foundation

struct AIChatLocation: Equatable {
    let path: String
    let line: Int

    init?(_ text: String) {
        guard let colon = text.lastIndex(of: ":"), let line = Int(text[text.index(after: colon)...]), line > 0 else {
            return nil
        }
        let path = String(text[..<colon])
        guard !path.isEmpty else {
            return nil
        }
        self.path = path
        self.line = line
    }
}
