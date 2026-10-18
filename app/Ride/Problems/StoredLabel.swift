import Foundation

struct StoredLabel: Equatable, Hashable {
    var path: String
    var byteStart: UInt32
    var byteEnd: UInt32
    var lineStart: UInt32
    var lineEnd: UInt32
    var column: UInt32
    var text: String?
    var macroName: String?
}

enum StoredNoteLevel: Equatable, Hashable {
    case error
    case warning
    case note
    case help
}

struct StoredNote: Equatable, Hashable {
    var level: StoredNoteLevel
    var message: String
    var labels: [StoredLabel]
}
