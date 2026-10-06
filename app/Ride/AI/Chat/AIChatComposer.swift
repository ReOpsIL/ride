import SwiftUI

struct AIChatComposer: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: AIChatStore
    @ObservedObject private var ts = ThemeStore.shared
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            chips
            GrowingTextEditor(
                text: $store.input,
                placeholder: "Ask about the code… (↩ sends, ⇧↩ new line)",
                lines: 1...10,
                focus: $focused,
                onReturn: send
            )
            .padding(Tokens.Space.xs)
            .background(ts.ui.bgRaised, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.s).stroke(ts.ui.border))
            HStack(spacing: Tokens.Space.s) {
                Button("Selection") { state.addSelectionToChat() }
                    .help(Shortcuts.help("Add the selection and its definitions", "Code › Add Selection to Chat"))
                Button("File") { state.addFileToChat() }
                    .help("Attach the whole current file")
                Spacer(minLength: 0)
                if store.streaming {
                    Button("Stop") { store.stop() }
                } else {
                    Button("Send", action: send)
                        .buttonStyle(.borderedProminent)
                        .disabled(store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .controlSize(.small)
        }
        .padding(Tokens.Space.m)
        .onAppear(perform: takeFocus)
        .onChange(of: store.focusInput) { _, _ in takeFocus() }
    }

    @ViewBuilder
    private var chips: some View {
        if !store.pending.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.xs) {
                    ForEach(store.pending) { attachment in
                        HStack(spacing: 3) {
                            Text(attachment.label)
                                .font(Tokens.mono(10))
                            Button {
                                store.detach(attachment.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(ts.ui.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ts.ui.bgHover, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
                        .help(attachment.kind.rawValue + " · " + attachment.path)
                    }
                }
            }
        }
    }

    private func send() {
        state.sendChat()
    }

    private func takeFocus() {
        guard store.focusInput else {
            return
        }
        store.focusInput = false
        focused = true
    }
}
