import SwiftUI

struct NewProjectSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var name = ""
    @State private var language = ProjectLanguage.rust
    @State private var buildSystem = ProjectBuildSystem.cargo
    @State private var library = false
    @State private var location = AppState.defaultProjectLocation
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("New Project")
                .font(Tokens.ui(15, weight: .semibold))
            fields
            Text(preview)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let error {
                Text(error)
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.error)
            }
            HStack {
                Spacer()
                Button("Cancel") { state.showNewProjectSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(ProjectScaffold.validate(name: name) != nil)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 520)
        .onChange(of: language) { _, lang in
            if !lang.buildSystems.contains(buildSystem) {
                buildSystem = lang.buildSystems[0]
            }
        }
        .onChange(of: name) { _, _ in error = nil }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            LabeledContent("Name") {
                TextField("my-project", text: $name)
                    .font(Tokens.mono(11))
            }
            LabeledContent("Language") {
                Picker("", selection: $language) {
                    ForEach(ProjectLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            LabeledContent("Build") {
                Picker("", selection: $buildSystem) {
                    ForEach(language.buildSystems) { system in
                        Text(system.rawValue).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(language.buildSystems.count == 1)
            }
            if language == .rust {
                LabeledContent("Kind") {
                    Picker("", selection: $library) {
                        Text("Binary").tag(false)
                        Text("Library").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            LabeledContent("Location") {
                HStack(spacing: Tokens.Space.s) {
                    Text(location.path)
                        .font(Tokens.mono(11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose…") { chooseLocation() }
                }
            }
        }
    }

    private var preview: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ProjectScaffold.validate(name: trimmed) == nil else {
            return ProjectScaffold.validate(name: trimmed) ?? ""
        }
        return location.appendingPathComponent(trimmed).path + "/" + scaffold(trimmed).mainFile
    }

    private func scaffold(_ trimmed: String) -> ProjectScaffold {
        ProjectScaffold(name: trimmed, language: language, buildSystem: buildSystem, library: library)
    }

    private func chooseLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = location
        panel.message = "Choose the folder that will contain the new project"
        if panel.runModal() == .OK, let url = panel.url {
            location = url
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = ProjectScaffold.validate(name: trimmed) {
            error = message
            return
        }
        error = state.createProject(scaffold(trimmed), in: location)
    }
}
