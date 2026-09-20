import Foundation

enum AIAnswerText {
    static func code(in answer: String) -> String {
        var blocks: [String] = []
        var current: [String]?
        for line in answer.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if let open = current {
                    blocks.append(open.joined(separator: "\n"))
                    current = nil
                } else {
                    current = []
                }
                continue
            }
            current?.append(line)
        }
        if let open = current, !open.isEmpty {
            blocks.append(open.joined(separator: "\n"))
        }
        return blocks.isEmpty ? answer : blocks.joined(separator: "\n\n")
    }
}
