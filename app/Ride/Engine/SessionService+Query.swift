import Foundation

extension SessionService {
    func importEdit(document: BufferDocument, importPath: String, done: @escaping (TextEdit?) -> Void) {
        guard let id = document.sessionId else {
            done(nil)
            return
        }
        queue(id).async {
            let edit = RideEngineClient.shared.engine?.importEdit(sessionId: id, importPath: importPath)
            DispatchQueue.main.async {
                done(edit)
            }
        }
    }

    func signatureHelp(document: BufferDocument, cursorByte: UInt32, done: @escaping (SignatureHelp?) -> Void) {
        guard let id = document.sessionId else {
            done(nil)
            return
        }
        queue(id).async {
            let help = RideEngineClient.shared.engine?.signatureHelp(sessionId: id, cursorByte: cursorByte)
            DispatchQueue.main.async {
                done(help)
            }
        }
    }

    func quickDoc(document: BufferDocument, cursorByte: UInt32, done: @escaping (QuickDoc?) -> Void) {
        guard let id = document.sessionId else {
            done(nil)
            return
        }
        queue(id).async {
            let doc = RideEngineClient.shared.engine?.quickDoc(sessionId: id, cursorByte: cursorByte)
            DispatchQueue.main.async {
                done(doc)
            }
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
