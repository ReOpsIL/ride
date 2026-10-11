import SwiftUI

struct PreferencesView: View {
    private enum Pane: Hashable {
        case general
        case editor
        case tools
        case ai
    }

    @EnvironmentObject private var state: AppState

    var body: some View {
        let bind = PreferenceBindings(state: state)
        TabView {
            GeneralSettings(bind: bind)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Pane.general)
            EditorSettings(bind: bind)
                .tabItem { Label("Editor", systemImage: "text.alignleft") }
                .tag(Pane.editor)
            ToolsSettings(bind: bind)
                .tabItem { Label("Tools", systemImage: "hammer") }
                .tag(Pane.tools)
            AISettingsPane(bind: bind)
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(Pane.ai)
        }
        .frame(width: 460)
        .frame(minHeight: 300)
        .padding(.top, Tokens.Space.m)
    }
}
