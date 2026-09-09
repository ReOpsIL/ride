import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        if state.workspaceRoot == nil {
            welcome
        } else {
            EmptyEditorView()
        }
    }

    private var welcome: some View {
        ZStack {
            ts.editorBackground
            VStack(spacing: Tokens.Space.xxl) {
                VStack(spacing: Tokens.Space.m) {
                    mark
                    Text("Ride")
                        .font(Tokens.ui(24, weight: .semibold))
                        .foregroundStyle(ts.ui.textPrimary)
                    Text("Native Rust editor")
                        .font(Tokens.ui(13))
                        .foregroundStyle(ts.ui.textSecondary)
                }
                Button("Open Folder…") {
                    state.openFolder()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                recents
                RustSrcHint()
                shortcuts
            }
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mark: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: 96, height: 96)
            .shadow(color: .black.opacity(Tokens.Shadow.popover.opacity), radius: Tokens.Shadow.popover.radius, y: Tokens.Shadow.popover.y)
    }

    @ViewBuilder
    private var recents: some View {
        if !state.recent.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Recent")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                ForEach(state.recent.prefix(6), id: \.self) { url in
                    RecentRow(url: url)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shortcuts: some View {
        Grid(alignment: .leading, horizontalSpacing: Tokens.Space.xl, verticalSpacing: Tokens.Space.xs) {
            ForEach(Self.hints, id: \.0) { hint in
                GridRow {
                    KeyCap(key: hint.0, size: 11)
                    Text(hint.1)
                        .font(Tokens.ui(11))
                        .foregroundStyle(ts.ui.textTertiary)
                }
            }
        }
    }

    private static let hints = [
        ("⌘P", "Open quickly"),
        ("⇧⌘R", "Go to symbol in project"),
        ("⇧⌘F", "Find in project"),
        ("⌘B", "Check with cargo"),
        ("F12", "Go to definition"),
        ("⌘/", "All shortcuts"),
    ]
}

private struct RecentRow: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false
    let url: URL

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: "folder.fill")
                .foregroundStyle(ts.ui.textSecondary)
            Text(url.lastPathComponent)
                .font(Tokens.ui(12, weight: .medium))
                .foregroundStyle(ts.ui.textPrimary)
            Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? ts.ui.bgHover : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.m))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            state.open(url)
        }
    }
}
