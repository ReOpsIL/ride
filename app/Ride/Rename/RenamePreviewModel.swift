import Foundation

final class RenamePreviewModel: ObservableObject {
    @Published var selection = RenameSelection()

    func load(name: String, newName: String, files: [RenamePreviewFile], review: [RenameReviewRow]) {
        selection = RenameSelection(name: name, newName: newName, files: files, review: review)
    }

    func clear() {
        selection = RenameSelection()
    }
}
