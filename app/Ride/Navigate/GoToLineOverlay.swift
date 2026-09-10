import SwiftUI

struct GoToLineOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        PickerCard(
            query: $state.goToLineQuery,
            placeholder: "Line or line:column",
            width: 360,
            hints: [
                PickerHint(id: "go", key: "↩", label: "go"),
                PickerHint(id: "esc", key: "esc", label: "dismiss"),
            ],
            trailing: "of \(lineCount)",
            onSubmit: { state.confirmGoToLine() },
            onDismiss: { state.showGoToLine = false }
        ) {
            PickerEmpty(text: hint)
        }
    }

    private var lineCount: Int {
        EditorJump.shared.view?.lineIndex().lineCount ?? 0
    }

    private var hint: String {
        let line = Int(state.goToLineQuery.split(separator: ":").first ?? "") ?? 0
        if line < 1 {
            return "Currently at line \(state.cursorLine)"
        }
        return line > lineCount ? "Past the last line, jumps to line \(lineCount)" : "Go to line \(line)"
    }
}
