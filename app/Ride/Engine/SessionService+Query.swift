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
}
