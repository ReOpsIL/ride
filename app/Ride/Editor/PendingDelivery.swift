import AppKit

struct PendingText {
    enum Disk {
        case dirty
        case save
        case clean
    }

    let text: String
    let disk: Disk
}

enum PendingJump {
    case byte(UInt32)
    case utf16(Int)
    case line(Int, mark: Bool)
}

extension AppState {
    func deliver(_ text: String, to buffer: BufferDocument, disk: PendingText.Disk) {
        buffer.pendingText = PendingText(text: text, disk: disk)
        if let host = EditorPanes.shared.host(bound: buffer) {
            flushPending(host)
        }
    }

    func jump(to target: PendingJump, in buffer: BufferDocument) {
        buffer.pendingJump = target
        if let host = EditorPanes.shared.host(bound: buffer) {
            flushPending(host)
        }
    }

    func openFile(_ url: URL, at target: PendingJump, readOnly: Bool = false) {
        openFile(url, readOnly: readOnly)
        if let buffer = buffer(for: url) {
            jump(to: target, in: buffer)
        }
    }

    func flushPending(_ host: EditorHostView) {
        guard let document = host.document else {
            return
        }
        if let pending = document.pendingText {
            document.pendingText = nil
            apply(pending, to: document, host: host)
        }
        if let target = document.pendingJump {
            document.pendingJump = nil
            perform(target, host: host)
        }
    }

    func refreshView(of buffer: BufferDocument) {
        guard let host = EditorPanes.shared.host(bound: buffer) else {
            return
        }
        apply(PendingText(text: buffer.text, disk: .clean), to: buffer, host: host)
    }

    private func apply(_ pending: PendingText, to document: BufferDocument, host: EditorHostView) {
        let view = host.textView
        let line = view.lineIndex().line(at: view.selectedRange().location)
        document.text = pending.text
        host.replaceText(pending.text)
        host.jump(toLine: line, focus: host === EditorPanes.shared.focused)
        SessionService.shared.resync(document: document, view: view)
        switch pending.disk {
        case .save:
            try? document.save(from: view, lineEndings: prefs.lineEndings)
            didSave(document, allowFormat: false)
        case .dirty:
            document.isDirty = true
            scheduleAutoSave(document)
        case .clean:
            document.isDirty = false
        }
    }

    private func perform(_ target: PendingJump, host: EditorHostView) {
        switch target {
        case .byte(let byte):
            host.jump(byte: byte)
            recordLocation()
        case .utf16(let location):
            host.select(NSRange(location: location, length: 0))
        case .line(let line, let mark):
            host.jump(toLine: line)
            if mark {
                HighlightApply.markLine(host.textView, line: line)
            }
        }
    }
}
