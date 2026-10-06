import SwiftUI

extension GitChangeKind {
    var letter: String {
        switch self {
        case .modified: return "M"
        case .typeChanged: return "T"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "U"
        case .conflicted: return "!"
        }
    }

    var label: String {
        switch self {
        case .modified: return "Modified"
        case .typeChanged: return "Type changed"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .conflicted: return "Conflicted"
        }
    }

    func color(_ ui: ChromeStyle) -> Color {
        switch self {
        case .modified, .typeChanged, .renamed, .copied: return ui.info
        case .added, .untracked: return ui.success
        case .deleted: return ui.textTertiary
        case .conflicted: return ui.error
        }
    }
}

extension GitFileChange {
    var shownKind: GitChangeKind? {
        unstaged ?? staged
    }

    var name: String {
        (path as NSString).lastPathComponent
    }

    var directory: String {
        (path as NSString).deletingLastPathComponent
    }

    func kind(on side: GitDiffSide) -> GitChangeKind? {
        side == .staged ? staged : unstaged
    }
}
