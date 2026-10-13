import SwiftUI

struct MapGrid: View {
    let viewport: MapViewport

    var body: some View {
        Canvas { context, size in
            let spacing = max(8, 22 * viewport.zoom)
            var path = Path()
            var x = firstLine(for: viewport.pan.width, spacing: spacing)
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y = firstLine(for: viewport.pan.height, spacing: spacing)
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(.primary.opacity(0.07)), lineWidth: 1)
        }
    }

    private func firstLine(for offset: CGFloat, spacing: CGFloat) -> CGFloat {
        let remainder = offset.truncatingRemainder(dividingBy: spacing)
        return remainder >= 0 ? remainder : remainder + spacing
    }
}

struct MapZoomChrome: View {
    let zoom: CGFloat
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onZoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out")
            .accessibilityLabel("Zoom out")
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 44)
            Button(action: onZoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in")
            .accessibilityLabel("Zoom in")
            Button(action: onReset) {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .help("Fit the map")
            .accessibilityLabel("Fit the map")
        }
        .buttonStyle(.borderless)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(10)
    }
}

struct MapArrangeChrome: View {
    let selected: MapArrange?
    let onSelect: (MapArrange) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            button(.fruchtermanReingold, "Fruchterman–Reingold", "Lay out with Fruchterman–Reingold")
            button(.kamadaKawai, "Kamada–Kawai", "Lay out with stress majorization (Kamada–Kawai)")
            button(.sugiyama, "Sugiyama", "Lay out in layers (Sugiyama)")
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(10)
    }

    private func button(_ kind: MapArrange, _ title: String, _ help: String) -> some View {
        Button(title) { onSelect(kind) }
            .buttonStyle(.borderless)
            .font(.caption.weight(selected == kind ? .bold : .regular))
            .foregroundStyle(selected == kind ? Color.accentColor : Color.secondary)
            .help(help)
            .accessibilityLabel(help)
    }
}
