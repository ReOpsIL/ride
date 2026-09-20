import Foundation

final class RenamePreviewModel: ObservableObject {
    @Published var selection = RenameSelection()
    @Published var title = ""
    @Published var applyTitle = "Rename"
    @Published var reviewTitle = "Review — could not verify these are the same symbol"

    func load(
        name: String,
        newName: String,
        files: [RenamePreviewFile],
        review: [RenameReviewRow],
        title: String,
        applyTitle: String,
        reviewTitle: String
    ) {
        selection = RenameSelection(name: name, newName: newName, files: files, review: review)
        self.title = title
        self.applyTitle = applyTitle
        self.reviewTitle = reviewTitle
    }

    func clear() {
        selection = RenameSelection()
        title = ""
        applyTitle = "Rename"
        reviewTitle = "Review — could not verify these are the same symbol"
    }
}
