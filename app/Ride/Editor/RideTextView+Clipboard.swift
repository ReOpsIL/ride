import AppKit

extension RideTextView {
    override func copy(_ sender: Any?) {
        guard selectedRange().length == 0 else {
            super.copy(sender)
            return
        }
        let line = (string as NSString).lineRange(for: selectedRange())
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString((string as NSString).substring(with: line), forType: .string)
    }

    override func cut(_ sender: Any?) {
        guard selectedRange().length == 0 else {
            super.cut(sender)
            return
        }
        copy(sender)
        let line = (string as NSString).lineRange(for: selectedRange())
        replaceText(in: line, with: "")
        setSelectedRange(NSRange(location: min(line.location, (string as NSString).length), length: 0))
    }
}
