import SwiftUI

struct FindBar: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $state.findQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .focused($focused)
                .onSubmit {
                    state.findNext()
                }
            Button("Next") {
                state.findNext()
            }
            Button("Previous") {
                state.findPrevious()
            }
            TextField("Replace", text: $state.replaceQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
            Button("Replace") {
                state.replaceOne()
            }
            Button("All") {
                state.replaceAll()
            }
            Spacer()
            Button {
                state.showFind = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            focused = true
        }
        .onExitCommand {
            state.showFind = false
        }
    }
}
