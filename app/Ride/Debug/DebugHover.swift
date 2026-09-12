import AppKit

enum DebugHover {
    static func content(view: NSTextView, range: NSRange) -> HoverContent? {
        let text = view.string as NSString
        guard range.location + range.length <= text.length else {
            return nil
        }
        return content(expression: text.substring(with: range))
    }

    static func content(expression: String) -> HoverContent? {
        let model = DebugPanelModel.shared
        guard DebugController.shared.isStopped, model.selectedFrame != nil else {
            return nil
        }
        let row = model.evaluate(expression, context: .hover)
        guard !row.failed, !row.value.isEmpty else {
            return nil
        }
        return HoverContent(
            signature: "\(expression) = \(row.value)",
            doc: row.typeName ?? "",
            origin: "debug"
        )
    }
}
