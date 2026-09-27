import Foundation

extension SessionService {
    func importEdit(document: BufferDocument, importPath: String, done: @escaping (TextEdit) -> Void) {
        read(document, delivery: .currentText, { engine, id in
            engine.importEdit(sessionId: id, importPath: importPath)
        }, then: { edit in
            if let edit {
                done(edit)
            }
        })
    }

    func signatureHelp(document: BufferDocument, cursorByte: UInt32, done: @escaping (SignatureHelp?) -> Void) {
        if !read(document, { $0.signatureHelp(sessionId: $1, cursorByte: cursorByte) }, then: done) {
            done(nil)
        }
    }

    func quickDoc(document: BufferDocument, cursorByte: UInt32, done: @escaping (QuickDoc?) -> Void) {
        if !read(document, { $0.quickDoc(sessionId: $1, cursorByte: cursorByte) }, then: done) {
            done(nil)
        }
    }

    func quickDefinition(document: BufferDocument, cursorByte: UInt32, done: @escaping ([DefinitionExcerpt]) -> Void) {
        let started = read(document, lane: .workspace, {
            $0.quickDefinition(sessionId: $1, cursorByte: cursorByte)
        }, then: done)
        if !started {
            done([])
        }
    }

    func quickDoc(path: String, byte: UInt32, done: @escaping (QuickDoc?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let engine = RideEngineClient.shared.engine
            let opened = try? engine?.openSession(
                bufferId: UUID().uuidString,
                path: path,
                text: text,
                visible: nil
            )
            let doc = opened.flatMap { engine?.quickDoc(sessionId: $0.sessionId, cursorByte: byte) }
            if let id = opened?.sessionId {
                engine?.closeSession(sessionId: id)
            }
            DispatchQueue.main.async {
                done(doc)
            }
        }
    }
}
