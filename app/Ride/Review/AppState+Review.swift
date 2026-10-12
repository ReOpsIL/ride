import Foundation

extension AppState {
    func openReviewRow(_ row: ReviewRow) {
        review.select(row, root: git.root)
        guard let url = git.map?.url(row.path), FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        openFile(url, at: .byte(row.startByte))
    }

    func reviewMark(_ row: ReviewRow, kind: String) {
        review.mark(row, root: git.root, kind: kind, note: review.noteDraft)
    }
}
