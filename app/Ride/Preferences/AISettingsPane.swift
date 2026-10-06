import SwiftUI

struct AISettingsPane: View {
    let bind: PreferenceBindings
    @EnvironmentObject private var state: AppState
    @State private var anthropicKey = ""
    @State private var openRouterKey = ""
    @FocusState private var focusedAccount: String?
    @State private var testResult = ""
    @State private var editingCustom = false
    @State private var editingCustomChat = false

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
                Picker("Provider", selection: bind.provider) {
                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.title).tag(provider.rawValue)
                    }
                }
                if state.prefs.aiProvider == AIProvider.openrouter.rawValue {
                    keyField("OpenRouter API key", text: $openRouterKey, account: OpenRouterChat.keyAccount)
                } else {
                    keyField("Anthropic API key", text: $anthropicKey, account: AnthropicMessages.keyAccount)
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
            Section("Chat and Explain") {
                Picker("Model", selection: chatModelSelection) {
                    ForEach(config.provider.chatPresets) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                    Text("Custom…").tag(AIModelChoice.custom)
                }
                if chatModelSelection.wrappedValue == AIModelChoice.custom {
                    TextField("Model ID", text: chatModelText, prompt: Text(config.provider.defaultChatModel))
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
        .onAppear {
            anthropicKey = Keychain.read(AnthropicMessages.keyAccount) ?? ""
            openRouterKey = Keychain.read(OpenRouterChat.keyAccount) ?? ""
        }
        .onDisappear {
            if let focusedAccount {
                commitKey(focusedAccount)
            }
        }
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: { AIModelChoice.selection(model: state.prefs.aiModel, presets: config.provider.presets, editingCustom: editingCustom) },
            set: { value in
                editingCustom = value == AIModelChoice.custom
                if !editingCustom {
                    state.updatePrefs { $0.aiModel = value }
                }
            }
        )
    }

    private var chatModelSelection: Binding<String> {
        Binding(
            get: { AIModelChoice.selection(model: state.prefs.assistant.chatModel, presets: config.provider.chatPresets, editingCustom: editingCustomChat) },
            set: { value in
                editingCustomChat = value == AIModelChoice.custom
                if !editingCustomChat {
                    state.updatePrefs { $0.assistant.chatModel = value }
                }
            }
        )
    }

    private var chatModelText: Binding<String> {
        Binding(
            get: { state.prefs.assistant.chatModel },
            set: { value in state.updatePrefs { $0.assistant.chatModel = value } }
        )
    }

    private var config: AIConfig {
        state.prefs.aiConfig
    }

    private func keyField(_ title: String, text: Binding<String>, account: String) -> some View {
        SecureField(title, text: text, prompt: Text("Stored in the keychain"))
            .focused($focusedAccount, equals: account)
            .onSubmit { commitKey(account) }
            .onChange(of: focusedAccount) { previous, _ in
                if let previous {
                    commitKey(previous)
                }
            }
    }

    private func commitKey(_ account: String) {
        Keychain.write(account == OpenRouterChat.keyAccount ? openRouterKey : anthropicKey, account: account)
    }

    private func test() {
        commitKey(config.provider == .openrouter ? OpenRouterChat.keyAccount : AnthropicMessages.keyAccount)
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
