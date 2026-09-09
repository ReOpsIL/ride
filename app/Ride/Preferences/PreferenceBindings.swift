import SwiftUI

struct PreferenceBindings {
    let state: AppState

    func bool(_ key: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { state.prefs[keyPath: key] },
            set: { value in state.updatePrefs { $0[keyPath: key] = value } }
        )
    }

    func int(_ key: WritableKeyPath<Preferences, Int>) -> Binding<Int> {
        Binding(
            get: { state.prefs[keyPath: key] },
            set: { value in state.updatePrefs { $0[keyPath: key] = value } }
        )
    }

    var theme: Binding<String> {
        Binding(
            get: { state.prefs.theme },
            set: { value in state.updatePrefs { $0.theme = value } }
        )
    }
}
