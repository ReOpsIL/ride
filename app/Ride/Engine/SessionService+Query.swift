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

    func quickDefinition(document: BufferDocument, cursorByte: UInt32, done: @escaping ([DefinitionExcerpt]) -> Void) {
        guard let id = document.sessionId else {
            done([])
            return
        }
        queue(id).async {
            let excerpts = RideEngineClient.shared.engine?.quickDefinition(sessionId: id, cursorByte: cursorByte) ?? []
            DispatchQueue.main.async {
                done(excerpts)
            }
        }
    }

    func quickDoc(path: String, byte: UInt32, name: String? = nil, done: @escaping (QuickDoc?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let at = Self.nameByte(in: text, name: name, from: byte)
            let engine = RideEngineClient.shared.engine
            let opened = try? engine?.openSession(
                bufferId: UUID().uuidString,
                path: path,
                text: text,
                visible: nil
            )
            let doc = opened.flatMap { engine?.quickDoc(sessionId: $0.sessionId, cursorByte: at) }
            if let id = opened?.sessionId {
                engine?.closeSession(sessionId: id)
            }
            DispatchQueue.main.async {
                done(doc)
            }
        }
    }

    private static func nameByte(in text: String, name: String?, from byte: UInt32) -> UInt32 {
        guard let name, !name.isEmpty else {
            return byte
        }
        let ns = text as NSString
        let from = min(Utf16.utf16Offset(in: text, utf8: Int(byte)), ns.length)
        let range = ns.range(of: name, options: [], range: NSRange(location: from, length: ns.length - from))
        guard range.location != NSNotFound else {
            return byte
        }
        return UInt32(Utf16.utf8Offset(in: text, utf16: range.location))
    }
}
