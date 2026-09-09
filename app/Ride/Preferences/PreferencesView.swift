import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let bind = PreferenceBindings(state: state)
        TabView {
            GeneralSettings(bind: bind)
                .tabItem { Label("General", systemImage: "gearshape") }
            EditorSettings(bind: bind)
                .tabItem { Label("Editor", systemImage: "text.alignleft") }
            ToolsSettings(bind: bind)
                .tabItem { Label("Tools", systemImage: "hammer") }
        }
        .frame(width: 460)
        .frame(minHeight: 300)
        .padding(.top, Tokens.Space.m)
    }
}
