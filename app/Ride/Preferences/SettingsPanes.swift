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
                Stepper(value: bind.int(\.fontSize), in: Preferences.fontSizes) {
                    LabeledContent("Font size", value: "\(state.prefs.fontSize) pt")
                }
                Stepper(value: bind.int(\.tabWidth), in: 2...8) {
                    LabeledContent("Tab width", value: "\(state.prefs.tabWidth) spaces")
                }
                Picker("Line endings", selection: bind.string(\.lineEndings)) {
                    Text("Keep").tag(LineEndings.keep)
                    Text("Convert to LF").tag(LineEndings.lf)
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
            }
            Section("Popups") {
                Toggle("Completions as you type", isOn: bind.bool(\.completions))
                Toggle("AI suggestions in the completion popup", isOn: bind.bool(\.aiComplete))
                Toggle("Cheat sheet with completions", isOn: bind.bool(\.cheatSheet))
                Toggle("Signature help", isOn: bind.bool(\.signatureHelp))
                Toggle("Documentation on hover", isOn: bind.bool(\.hoverDocs))
            }
            Section("Display") {
                Toggle("Outline panel", isOn: bind.bool(\.outlinePanel))
                Toggle("Line numbers", isOn: bind.bool(\.lineNumbers))
                Toggle("Soft wrap", isOn: bind.bool(\.softWrap))
                Toggle("Indent guides", isOn: bind.bool(\.indentGuides))
                Toggle("Visible whitespace", isOn: bind.bool(\.visibleWhitespace))
                Toggle("Code vision", isOn: bind.bool(\.codeVision))
            }
        }
        .formStyle(.grouped)
    }
}

struct ToolsSettings: View {
    let bind: PreferenceBindings
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Check on save and while typing", isOn: bind.bool(\.checkOnSave))
                Toggle("Use Clippy for live Rust diagnostics", isOn: bind.bool(\.useClippy))
                    .disabled(!state.prefs.checkOnSave)
            }
            Section("Formatting") {
                Toggle("Format on save (rustfmt, clang-format)", isOn: bind.bool(\.formatOnSave))
            }
            Section("Tools") {
                Toggle("Check for missing tools at launch", isOn: bind.bool(\.askMissingTools))
            }
            Section("Command line") {
                RideCommandRow()
            }
        }
        .formStyle(.grouped)
    }
}
