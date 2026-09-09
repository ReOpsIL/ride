import SwiftUI

struct FileOutlineView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "list.bullet.indent", title: "Outline", badges: badges) {
                IconButton(symbol: "xmark", help: "Hide Outline", size: 9) {
                    state.updatePrefs { $0.outlinePanel = false }
                }
            }
            if let buffer = state.activeBuffer {
                OutlineList(buffer: buffer)
            } else {
                Text("No file")
                    .font(Tokens.ui(12))
                    .foregroundStyle(ts.ui.textTertiary)
                    .padding(Tokens.Space.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        guard let count = state.activeBuffer?.outline.count, count > 0 else {
            return []
        }
        return [PanelBadge(id: "count", text: "\(count)", tint: nil)]
    }
}

struct OutlineList: View {
    @ObservedObject var buffer: BufferDocument
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        if buffer.outline.isEmpty {
            Text("No symbols")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .padding(Tokens.Space.l)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(buffer.outline) { row in
                        OutlineRowView(row: row)
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }
}

struct OutlineRowView: View {
    let row: OutlineRow
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        let kind = OutlineKind.itemKind(row.kindLabel)
        HStack(spacing: Tokens.Space.s) {
            Text(CompletionRowStyle.glyph(kind))
                .font(Tokens.mono(9, weight: .bold))
                .foregroundStyle(Color(CompletionRowStyle.color(kind)))
                .frame(width: 24, height: 14)
                .background(Color(CompletionRowStyle.color(kind)).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
            Text(row.name)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.sidebarRow)
        .background(hovering ? ts.ui.bgHover : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            state.jumpTo(byte: row.startByte)
        }
    }
}

enum OutlineKind {
    static func itemKind(_ label: String) -> ItemKind {
        switch label {
        case "mod": return .mod
        case "struct": return .struct
        case "enum": return .enum
        case "union": return .union
        case "trait": return .trait
        case "fn": return .fn
        case "method": return .method
        case "macro": return .macro
        case "const": return .const
        case "static": return .static
        default: return .type
        }
    }
}
