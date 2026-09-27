import Foundation

final class SelfTestScratch {
    var zoomBefore = 0
    var body = ""
    var next = ""
    var buildLine = ""
    var staleRunId = 0
    var staleShown = false
    var saved = ""
}

struct SelfTestOpened {
    let bodyLine: Int
    let goToLine: Int
    let fileName: String
    let filePath: String

    static func from(_ state: AppState) -> SelfTestOpened {
        let url = state.activeBuffer?.fileURL
        let name = url?.lastPathComponent ?? "main.rs"
        let relative = url.flatMap { file in
            state.workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: file) }
        }
        switch state.activeBuffer?.language ?? BufferLanguage.of(url) {
        case .c, .cpp:
            return SelfTestOpened(bodyLine: 15, goToLine: 30, fileName: name, filePath: relative ?? "src/shapes.cpp")
        default:
            return SelfTestOpened(bodyLine: 10, goToLine: 15, fileName: name, filePath: relative ?? "src/main.rs")
        }
    }
}
