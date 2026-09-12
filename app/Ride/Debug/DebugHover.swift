import AppKit

enum DebugHover {
    static func request(
        view: NSTextView,
        range: NSRange,
        completion: @escaping (HoverContent?) -> Void
    ) -> Bool {
        let text = view.string as NSString
        guard range.location + range.length <= text.length else {
            return false
        }
        return request(expression: text.substring(with: range), completion: completion)
    }

    static func request(expression: String, completion: @escaping (HoverContent?) -> Void) -> Bool {
        let model = DebugPanelModel.shared
        guard DebugController.shared.isStopped, model.selectedFrame != nil else {
            return false
        }
        model.evaluate(expression, context: .hover) { row in
            guard let row, !row.failed, !row.value.isEmpty else {
                completion(nil)
                return
            }
            completion(HoverContent(
                signature: "\(expression) = \(row.value)",
                doc: row.typeName ?? "",
                origin: "debug"
            ))
        }
        return true
    }
}
