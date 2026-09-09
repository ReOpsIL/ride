import SwiftUI

struct TabStrip: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                if state.buffers.isEmpty {
                    Text("No Editor")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
                ForEach(state.buffers) { buffer in
                    TabChip(buffer: buffer, selected: buffer.id == state.activeID)
                }
            }
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct TabChip: View {
    @ObservedObject var buffer: BufferDocument
    let selected: Bool
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            Text(buffer.isDirty ? "●" : " ")
                .font(.system(size: 8))
                .foregroundStyle(buffer.isDirty ? Color.secondary : Color.clear)
            Text(buffer.displayName)
                .font(.system(size: 11))
                .lineLimit(1)
            Button {
                state.closeBuffer(buffer.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(selected ? Color(nsColor: .textBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            state.selectBuffer(buffer.id)
        }
    }
}
