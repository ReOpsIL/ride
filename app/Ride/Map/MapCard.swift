import SwiftUI

struct MapCard: View {
    @ObservedObject private var ts = ThemeStore.shared
    let node: MapNode
    let selected: Bool
    let scale: CGFloat
    let onOpen: () -> Void
    let onEnter: () -> Void

    var body: some View {
        let tint = MapTint.color(node.kind)
        VStack(alignment: .leading, spacing: 4 * scale) {
            HStack(spacing: 6 * scale) {
                Image(systemName: MapTint.symbol(node.kind))
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(tint)
                Text(node.detail.uppercased())
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if node.path != nil {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11 * scale, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ts.ui.textSecondary)
                    .help("Open \(node.title)")
                    .accessibilityLabel("Open \(node.title)")
                }
                if node.opens {
                    Button(action: onEnter) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10 * scale, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ts.ui.textTertiary)
                    .help("Open what is inside")
                    .accessibilityLabel("Open \(node.title) inside")
                }
            }
            Text(node.title)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(10 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous).fill(ts.ui.bgRaised))
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .stroke(selected ? ts.ui.accent : tint.opacity(0.55), lineWidth: (selected ? 2.4 : 1.2) * scale)
        )
        .shadow(color: .black.opacity(selected ? 0.28 : 0.12), radius: (selected ? 10 : 5) * scale, y: 2 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.opens ? "\(node.title), opens inner map" : node.title)
    }
}

enum MapTint {
    static func color(_ kind: MapKind) -> Color {
        switch kind {
        case .project: .cyan
        case .module: .blue
        case .file: .teal
        case .type: .orange
        case .function: .green
        case .value: .purple
        }
    }

    static func symbol(_ kind: MapKind) -> String {
        switch kind {
        case .project: "shippingbox"
        case .module: "square.stack.3d.up"
        case .file: "doc.text"
        case .type: "t.square"
        case .function: "function"
        case .value: "number"
        }
    }
}
