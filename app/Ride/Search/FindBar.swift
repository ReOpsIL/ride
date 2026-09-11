import SwiftUI

struct FindBar: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            field(icon: "magnifyingglass", placeholder: "Find", text: $state.findQuery, trailing: countLabel)
                .frame(width: 260)
                .focused($focused)
                .onSubmit {
                    state.findNext()
                }
            IconButton(symbol: "chevron.up", help: "Previous (⇧⌘G)") {
                state.findPrevious()
            }
            IconButton(symbol: "chevron.down", help: "Next (⌘G)") {
                state.findNext()
            }
            IconButton(symbol: "textformat", help: "Match case", active: state.findOptions.caseSensitive) {
                state.findOptions.caseSensitive.toggle()
            }
            IconButton(symbol: "textformat.abc.dottedunderline", help: "Whole word", active: state.findOptions.wholeWord) {
                state.findOptions.wholeWord.toggle()
            }
            IconButton(symbol: "asterisk", help: "Regular expression", active: state.findOptions.regex) {
                state.findOptions.regex.toggle()
            }
            IconButton(symbol: "arrow.left.arrow.right", help: "Replace (⌥⌘F)", active: state.showReplaceField) {
                state.showReplaceField.toggle()
            }
            if state.showReplaceField {
                field(icon: "pencil", placeholder: "Replace", text: $state.replaceQuery, trailing: nil)
                    .frame(width: 200)
                Button("Replace") {
                    state.replaceOne()
                }
                Button("All") {
                    state.replaceAll()
                }
            }
            Spacer(minLength: 0)
            IconButton(symbol: "xmark", help: "Close (esc)") {
                state.showFind = false
            }
        }
        .controlSize(.small)
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: 36)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .bottom) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
        .onAppear {
            focused = true
        }
        .onExitCommand {
            state.showFind = false
            EditorPanes.shared.focusedView?.window?.makeFirstResponder(EditorPanes.shared.focusedView)
        }
    }

    private var countLabel: String? {
        guard let text = state.activeBuffer?.text else {
            return nil
        }
        return FindCount.label(current: state.findRange, in: text, query: state.findQuery, options: state.findOptions)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, trailing: String?) -> some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Tokens.mono(12))
                .foregroundStyle(ts.ui.textPrimary)
            if let trailing {
                Text(trailing)
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textTertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: 24)
        .background(ts.ui.bgBase, in: RoundedRectangle(cornerRadius: Tokens.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.m).stroke(ts.ui.border, lineWidth: Tokens.Size.hairline))
    }
}
