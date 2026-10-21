import SwiftUI

struct RemoteSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var editor: RemoteEditor
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            header
            Toggle("Use for build, run, test, and debug", isOn: $editor.draft.enabled)
                .font(Tokens.ui(11))
            reach
            RemoteFields(editor: editor)
            Divider()
            RemoteProbeView(editor: editor)
            buttons
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 600)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Remote Toolchain")
                .font(Tokens.ui(15, weight: .semibold))
            Text("You edit on this Mac. Ride copies the project to the remote over SSH, then builds, runs, and debugs it there.")
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reach: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Picker("Connect via", selection: $editor.draft.kind) {
                ForEach(RemoteKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            Text(LocalizedStringKey(editor.draft.kind.summary))
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttons: some View {
        HStack {
            Button("Test Remote") { state.testRemote() }
                .disabled(editor.isTesting)
            if editor.isTesting {
                Button("Stop") { editor.stopTest() }
            }
            Spacer()
            Button("Cancel") { state.cancelRemote() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { state.saveRemote() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
