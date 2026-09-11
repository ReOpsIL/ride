import AppKit

extension EditorHostView {
    var docs: DocController {
        if let docsStorage {
            return docsStorage
        }
        let created = DocController()
        docsStorage = created
        return created
    }

    func closeDocs() {
        docsStorage?.hide()
    }

    func docsCaretMoved() {
        docsStorage?.caretMoved()
    }

    func hideUnpinnedDocs() {
        docsStorage?.hideIfUnpinned()
    }
}
