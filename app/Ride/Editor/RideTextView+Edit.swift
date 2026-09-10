import AppKit

extension RideTextView {
    func replaceText(in range: NSRange, with text: String) {
        guard shouldChangeText(in: range, replacementString: text) else {
            return
        }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
    }
}
