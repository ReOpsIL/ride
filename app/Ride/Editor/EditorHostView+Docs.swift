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

    var peek: PeekController {
        if let peekStorage {
            return peekStorage
        }
        let created = PeekController()
        peekStorage = created
        return created
    }

    func closeDocs() {
        docsStorage?.hide()
        peekStorage?.hide()
    }

    func docsCaretMoved() {
        docsStorage?.caretMoved()
        peekStorage?.caretMoved()
    }

    func hideUnpinnedDocs() {
        docsStorage?.hideIfUnpinned()
        peekStorage?.hideIfUnpinned()
    }
}
