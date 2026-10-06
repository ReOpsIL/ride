import AppKit

struct VisionLabel {
    let text: String
    let height: CGFloat
    let indent: CGFloat
    let padding: CGFloat
    let font: NSFont

    var frame: CGRect {
        VisionLayout.labelRect(
            extraHeight: height,
            indent: indent,
            labelSize: (text as NSString).size(withAttributes: attributes),
            padding: padding
        )
    }

    func draw(at point: CGPoint) {
        let rect = frame
        (text as NSString).draw(at: CGPoint(x: point.x + rect.minX, y: point.y + rect.minY), withAttributes: attributes)
    }

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: ThemeStore.shared.chrome.textTertiary]
    }
}
