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

    func font(for capture: CaptureKind, text: String) -> NSFont? {
        switch capture {
        case .strong: return bold
        case .emphasis: return italic
        case .heading: return heading(level: HeadingLevel.of(text))
        default: return nil
        }
    }

    private func heading(level: Int) -> NSFont? {
        guard let base else {
            return nil
        }
        let size = (base.pointSize * HeadingLevel.scale(level)).rounded()
        return NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }
}
