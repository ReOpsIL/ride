import CoreGraphics
import Foundation

enum VisionLayout {
    static func lineHeight(ascender: CGFloat, descender: CGFloat, leading: CGFloat) -> CGFloat {
        ceil(ascender - descender + leading)
    }

    static func indentWidth(prefix: String, spaceWidth: CGFloat, tabWidth: Int) -> CGFloat {
        var width: CGFloat = 0
        let tab = spaceWidth * CGFloat(tabWidth)
        for ch in prefix {
            if ch == "\t" {
                width += tab
            } else if ch == " " {
                width += spaceWidth
            } else {
                break
            }
        }
        return width
    }

    static func labelRect(
        extraHeight: CGFloat,
        indent: CGFloat,
        labelSize: CGSize,
        padding: CGFloat
    ) -> CGRect {
        let y = max(0, (extraHeight - labelSize.height) / 2)
        return CGRect(
            x: indent + padding,
            y: y,
            width: labelSize.width,
            height: labelSize.height
        )
    }
}
