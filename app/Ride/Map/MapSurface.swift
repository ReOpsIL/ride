import SwiftUI

struct MapSurface: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        MapPage(session: state.workspaceMap)
    }
}

private struct MapPage: View {
    @ObservedObject var session: MapSession
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            header(session)
            ZStack {
                if session.loading && session.stack.isEmpty {
                    ProgressView("Reading the workspace")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if session.graph.nodes.isEmpty {
                    Text(state.workspaceRoot == nil ? "Open a workspace to map it." : "Nothing in this folder to map.")
                        .foregroundStyle(ts.ui.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MapCanvas(
                        session: session,
                        onPress: { state.pressMapNode($0) },
                        onOpen: { state.openMapFile($0) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
        .onAppear { state.reloadWorkspaceMap(force: false) }
        .onChange(of: state.workspaceRoot) { _, _ in
            state.reloadWorkspaceMap(force: true)
        }
    }

    private func header(_ session: MapSession) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(ts.ui.textSecondary)
            if session.crumbs.count > 1 {
                Button {
                    state.workspaceMap.back(to: session.stack.count - 2)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Back")
                .accessibilityLabel("Back")
            }
            ForEach(Array(session.crumbs.enumerated()), id: \.offset) { index, title in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ts.ui.textTertiary)
                }
                if index < session.crumbs.count - 1 {
                    Button(title) { state.workspaceMap.back(to: index) }
                        .buttonStyle(.plain)
                        .foregroundStyle(ts.ui.accent)
                } else {
                    Text(title.isEmpty ? "Workspace" : title)
                        .foregroundStyle(ts.ui.textPrimary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            IconButton(symbol: "arrow.clockwise", help: "Read the workspace again", size: 11) {
                state.reloadWorkspaceMap(force: true)
            }
            IconButton(symbol: "xmark", help: "Hide the workspace map", size: 11) {
                state.toggleWorkspaceMap()
            }
        }
        .font(Tokens.ui(11, weight: .semibold))
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.panelHeader)
        .background(ts.ui.bgRaised)
    }
}
