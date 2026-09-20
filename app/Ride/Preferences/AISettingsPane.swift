import SwiftUI

struct AISettingsPane: View {
    let bind: PreferenceBindings
    @EnvironmentObject private var state: AppState
    @State private var anthropicKey = Keychain.read(AnthropicMessages.keyAccount) ?? ""
    @State private var openRouterKey = Keychain.read(OpenRouterChat.keyAccount) ?? ""
    @State private var testResult = ""
    @State private var editingCustom = false

    var body: some View {
        Form {
            Section("AI suggestions") {
                Toggle("Show AI suggestions in the completion popup", isOn: bind.bool(\.aiComplete))
                Picker("Context sent with each request", selection: bind.string(\.aiContext)) {
                    ForEach(AIContextLevel.allCases, id: \.rawValue) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
            }
            Section("Provider") {
                Picker("Provider", selection: bind.string(\.aiProvider)) {
                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.title).tag(provider.rawValue)
                    }
                }
                if state.prefs.aiProvider == AIProvider.openrouter.rawValue {
                    keyField("OpenRouter API key", text: $openRouterKey, account: OpenRouterChat.keyAccount)
                } else {
                    Picker("Sign in", selection: bind.string(\.aiAuth)) {
                        Text("Anthropic account").tag(AIAuthMode.login.rawValue)
                        Text("API key").tag(AIAuthMode.key.rawValue)
                    }
                    if state.prefs.aiAuth == AIAuthMode.key.rawValue {
                        keyField("Anthropic API key", text: $anthropicKey, account: AnthropicMessages.keyAccount)
                    } else {
                        AILoginRow()
                    }
                }
                Picker("Model", selection: modelSelection) {
                    ForEach(config.provider.presets) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                    Text("Custom…").tag(AIModelChoice.custom)
                }
                if modelSelection.wrappedValue == AIModelChoice.custom {
                    TextField("Model ID", text: bind.string(\.aiModel), prompt: Text(config.provider.defaultModel))
                        .font(Tokens.mono(12))
                }
            }
            Section("Check") {
                HStack {
                    Button("Test connection") { test() }
                    Text(testResult)
                        .font(Tokens.ui(11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: { AIModelChoice.selection(model: state.prefs.aiModel, provider: config.provider, editingCustom: editingCustom) },
            set: { value in
                editingCustom = value == AIModelChoice.custom
                if !editingCustom {
                    state.updatePrefs { $0.aiModel = value }
                }
            }
        )
    }

    private var config: AIConfig {
        AIConfig(provider: state.prefs.aiProvider, model: state.prefs.aiModel, auth: state.prefs.aiAuth, level: state.prefs.aiContext)
    }

    private func keyField(_ title: String, text: Binding<String>, account: String) -> some View {
        SecureField(title, text: text, prompt: Text("Stored in the keychain"))
            .onSubmit { Keychain.write(text.wrappedValue, account: account) }
            .onChange(of: text.wrappedValue) { _, value in Keychain.write(value, account: account) }
    }

    private func test() {
        testResult = "Testing…"
        let input = AIPromptInput(language: "Rust", path: "src/main.rs", prefix: "fn main() {\n    let total = 1 + ", suffix: ";\n}\n", extras: [])
        AIClient.complete({ input }, config: config) { result in
            switch result {
            case .success(let suggestions):
                testResult = suggestions.isEmpty ? "Connected, no suggestion returned" : "OK: \(suggestions[0].name)"
            case .failure(let error):
                testResult = error.message
            }
        }
    }
}

struct AILoginRow: View {
    @State private var profile: String?
    @State private var checking = true
    @State private var loggingIn = false

    var body: some View {
        HStack {
            if AnthropicLogin.executable == nil {
                Text("Needs the Anthropic CLI: \(AnthropicLogin.installCommand)")
                    .font(Tokens.ui(11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(AnthropicLogin.installCommand, forType: .string)
                }
            } else {
                Text(status)
                    .font(Tokens.ui(11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(profile == nil ? "Log in…" : "Log in again…") { login() }
                    .disabled(loggingIn)
            }
        }
        .onAppear(perform: refresh)
    }

    private var status: String {
        if loggingIn {
            return "Waiting for the browser sign-in…"
        }
        if checking {
            return "Checking…"
        }
        return profile.map { "Logged in (profile \($0))" } ?? "Not logged in"
    }

    private func refresh() {
        checking = true
        AnthropicLogin.status { found in
            profile = found
            checking = false
        }
    }

    private func login() {
        loggingIn = true
        AnthropicLogin.login { _ in
            loggingIn = false
            refresh()
        }
    }
}
