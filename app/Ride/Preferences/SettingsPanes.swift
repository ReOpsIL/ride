import SwiftUI

struct GeneralSettings: View {
    let bind: PreferenceBindings
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("Appearance") {
                ThemeSwatchPicker(selection: bind.theme)
            }
            Section("Text") {
                Stepper(value: bind.int(\.fontSize), in: 11...18) {
                    LabeledContent("Font size", value: "\(state.prefs.fontSize) pt")
                }
                Stepper(value: bind.int(\.tabWidth), in: 2...8) {
                    LabeledContent("Tab width", value: "\(state.prefs.tabWidth) spaces")
                }
            }
            Section("Files") {
                Toggle("Show hidden files", isOn: bind.bool(\.showHidden))
            }
        }
        .formStyle(.grouped)
    }
}

struct EditorSettings: View {
    let bind: PreferenceBindings

    var body: some View {
        Form {
            Section("Editing") {
                Toggle("Auto-save after 1 s", isOn: bind.bool(\.autoSave))
                Toggle("Completions as you type", isOn: bind.bool(\.completions))
            }
            Section("Display") {
                Toggle("Outline panel", isOn: bind.bool(\.outlinePanel))
                Toggle("Indent guides", isOn: bind.bool(\.indentGuides))
                Toggle("Visible whitespace", isOn: bind.bool(\.visibleWhitespace))
            }
        }
        .formStyle(.grouped)
    }
}

struct ToolsSettings: View {
    let bind: PreferenceBindings

    var body: some View {
        Form {
            Section("cargo check") {
                Toggle("Check on save", isOn: bind.bool(\.checkOnSave))
            }
            Section("rustfmt") {
                Toggle("Format on save", isOn: bind.bool(\.formatOnSave))
            }
        }
        .formStyle(.grouped)
    }
}
