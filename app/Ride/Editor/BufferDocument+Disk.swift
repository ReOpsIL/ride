import Foundation

struct DiskText {
    let text: String
    let crlf: Bool
}

extension BufferDocument {
    static func load(_ url: URL) -> DiskText? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let raw = String(decoding: data, as: UTF8.self)
        return DiskText(text: LineEndings.normalized(raw), crlf: raw.contains("\r\n"))
    }

    func readDisk() -> DiskText? {
        fileURL.flatMap(Self.load)
    }

    func markLoaded(_ loaded: DiskText) {
        diskText = loaded.text
        usesCRLF = loaded.crlf
        changedOnDisk = false
        isDirty = false
    }

    func differsFromDisk() -> Bool {
        guard let loaded = readDisk() else {
            return false
        }
        return loaded.text != diskText
    }

    var lineEnding: String {
        usesCRLF ? "CRLF" : "LF"
    }

    func useLineEnding(crlf: Bool) {
        guard usesCRLF != crlf else {
            return
        }
        usesCRLF = crlf
        isDirty = true
        objectWillChange.send()
    }

    func save(from textView: RideTextView?, lineEndings: String = LineEndings.keep) throws {
        if let textView {
            text = textView.string
        }
        guard let fileURL, !isReadOnly else {
            return
        }
        let encoded = LineEndings.encode(text: text, usesCRLF: usesCRLF, policy: lineEndings)
        try encoded.text.write(to: fileURL, atomically: true, encoding: .utf8)
        usesCRLF = encoded.usesCRLF
        diskText = text
        changedOnDisk = false
        isDirty = false
        RideEngineClient.shared.engine?.workspaceFileChanged(path: fileURL.path)
    }
}
