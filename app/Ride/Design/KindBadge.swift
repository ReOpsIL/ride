import AppKit
import SwiftUI

enum KindStyle {
    static func letter(_ kind: ItemKind) -> String {
        switch kind {
        case .keyword: return "k"
        case .local: return "l"
        case .crate: return "C"
        case .mod: return "M"
        case .`struct`: return "S"
        case .`enum`: return "E"
        case .union: return "U"
        case .trait: return "T"
        case .fn: return "f"
        case .method: return "m"
        case .macro: return "!"
        case .const: return "c"
        case .type: return "t"
        case .`static`: return "s"
        case .heading: return "#"
        case .`class`: return "C"
        case .namespace: return "N"
        case .field: return "p"
        case .table: return "["
        case .target: return ">"
        }
    }

    static func color(_ kind: ItemKind) -> NSColor {
        CompletionRowStyle.color(kind)
    }
}

struct KindBadge: View {
    let kind: ItemKind
    var size: CGFloat = Tokens.Size.badge

    var body: some View {
        let color = Color(KindStyle.color(kind))
        Text(KindStyle.letter(kind))
            .font(.system(size: size * 0.6, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: Tokens.Radius.s, style: .continuous))
    }
}

final class KindBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Tokens.Radius.s
        layer?.cornerCurve = .continuous
        label.font = NSFont.monospacedSystemFont(ofSize: Tokens.Size.badge * 0.6, weight: .bold)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: Tokens.Size.badge),
            heightAnchor.constraint(equalToConstant: Tokens.Size.badge),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ kind: ItemKind) {
        let color = KindStyle.color(kind)
        label.stringValue = KindStyle.letter(kind)
        label.textColor = color
        layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
    }
}
