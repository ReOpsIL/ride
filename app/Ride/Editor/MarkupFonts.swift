import AppKit

struct MarkupFonts {
    let base: NSFont?
    let bold: NSFont?
    let italic: NSFont?

    init(base: NSFont?) {
        self.base = base
        let manager = NSFontManager.shared
        bold = base.map { manager.convert($0, toHaveTrait: .boldFontMask) }
        italic = base.map { manager.convert($0, toHaveTrait: .italicFontMask) }
    }

    func font(for capture: CaptureKind) -> NSFont? {
        switch capture {
        case .strong: return bold
        case .emphasis: return italic
        case .heading: return bold
        default: return nil
        }
    }
}
