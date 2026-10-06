import SwiftUI

struct GrowingTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let lines: ClosedRange<Int>
    var focus: FocusState<Bool>.Binding
    var onReturn: (() -> Void)?
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        Text(text + " ")
            .lineLimit(lines)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .overlay {
                ZStack(alignment: .topLeading) {
                    editor
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(ts.ui.textTertiary)
                            .padding(.leading, 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
            }
            .font(Tokens.ui(12))
    }

    private var editor: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .focused(focus)
            .onKeyPress(.return, phases: .down) { press in
                guard let onReturn, !press.modifiers.contains(.shift) else {
                    return .ignored
                }
                onReturn()
                return .handled
            }
    }
}
