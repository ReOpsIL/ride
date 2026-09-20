import Foundation

struct RenamePreviewFile: Equatable {
    let path: String
    let count: Int
}

struct RenameReviewRow: Equatable {
    let id: Int
    let path: String
    let count: Int

    var label: String {
        path
    }
}

struct RenameSelection: Equatable {
    var name = ""
    var newName = ""
    var files: [RenamePreviewFile] = []
    var review: [RenameReviewRow] = []
    var includedFiles: Set<String> = []
    var includedReview: Set<Int> = []

    init() {}

    init(name: String, newName: String, files: [RenamePreviewFile], review: [RenameReviewRow]) {
        self.name = name
        self.newName = newName
        self.files = files
        self.review = review
        includedFiles = Set(files.map(\.path))
        includedReview = []
    }

    var showBanner: Bool {
        files.isEmpty
    }

    var chosenFilePaths: [String] {
        files.filter { includedFiles.contains($0.path) }.map(\.path)
    }

    var chosenReviewIds: [Int] {
        review.filter { includedReview.contains($0.id) }.map(\.id)
    }

    var chosenTargetCount: Int {
        chosenFilePaths.count + chosenReviewIds.count
    }

    var chosenEditCount: Int {
        let fileEdits = files.filter { includedFiles.contains($0.path) }.reduce(0) { $0 + $1.count }
        let reviewEdits = review.filter { includedReview.contains($0.id) }.reduce(0) { $0 + $1.count }
        return fileEdits + reviewEdits
    }

    var canApply: Bool {
        !chosenFilePaths.isEmpty || !chosenReviewIds.isEmpty
    }

    var allReviewSelected: Bool {
        !review.isEmpty && includedReview.count == review.count
    }

    func isFile(_ path: String) -> Bool {
        includedFiles.contains(path)
    }

    func isReview(_ id: Int) -> Bool {
        includedReview.contains(id)
    }

    mutating func setFile(_ path: String, _ on: Bool) {
        if on {
            includedFiles.insert(path)
        } else {
            includedFiles.remove(path)
        }
    }

    mutating func setReview(_ id: Int, _ on: Bool) {
        if on {
            includedReview.insert(id)
        } else {
            includedReview.remove(id)
        }
    }

    mutating func selectAllFiles(_ on: Bool) {
        includedFiles = on ? Set(files.map(\.path)) : []
    }

    mutating func selectAllReview(_ on: Bool) {
        includedReview = on ? Set(review.map(\.id)) : []
    }

    static func reviewRows(from review: [RenamePreviewFile]) -> [RenameReviewRow] {
        review.enumerated().map { index, file in
            RenameReviewRow(id: index, path: file.path, count: file.count)
        }
    }
}
