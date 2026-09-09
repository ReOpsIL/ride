import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Picker("Theme", selection: themeBinding) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
            }
            Stepper(value: fontBinding, in: 11...18) {
                Text("Font size  \(state.prefs.fontSize) pt")
            }
            Stepper(value: tabBinding, in: 2...8) {
                Text("Tab width  \(state.prefs.tabWidth)")
            }
            Toggle("Auto-save", isOn: boolBinding(\.autoSave))
            Toggle("Completions", isOn: boolBinding(\.completions))
            Toggle("Outline panel", isOn: boolBinding(\.outlinePanel))
            Toggle("Visible whitespace", isOn: boolBinding(\.visibleWhitespace))
            Toggle("Show hidden files", isOn: boolBinding(\.showHidden))
            Toggle("Check on save", isOn: boolBinding(\.checkOnSave))
            Toggle("Format on save", isOn: boolBinding(\.formatOnSave))
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding(12)
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { state.prefs.theme },
            set: { value in state.updatePrefs { $0.theme = value } }
        )
    }

    private var fontBinding: Binding<Int> {
        Binding(
            get: { state.prefs.fontSize },
            set: { value in state.updatePrefs { $0.fontSize = value } }
        )
    }

    private var tabBinding: Binding<Int> {
        Binding(
            get: { state.prefs.tabWidth },
            set: { value in state.updatePrefs { $0.tabWidth = value } }
        )
    }

    private func boolBinding(_ key: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { state.prefs[keyPath: key] },
            set: { value in state.updatePrefs { $0[keyPath: key] = value } }
        )
    }
}
