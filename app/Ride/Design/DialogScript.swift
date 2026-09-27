import Foundation

enum CloseChoice {
    case save
    case discard
    case cancel
}

enum OverwriteChoice {
    case overwrite
    case reload
    case cancel
}

struct ScriptedName {
    let name: String?
}

struct ScriptedURL {
    let url: URL?
}

enum DialogScript {
    static var answers: [Any] = []

    static var pending: Int {
        answers.count
    }

    static func push(_ values: Any...) {
        answers.append(contentsOf: values)
    }

    static func clear() {
        answers.removeAll()
    }

    static func next<T>(_ type: T.Type) -> T? {
        guard let first = answers.first as? T else {
            return nil
        }
        answers.removeFirst()
        return first
    }
}
