import SwiftUI

struct FileOutlineView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            if let buffer = state.activeBuffer {
                OutlineList(buffer: buffer)
            } else {
                Text("No file")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .leading) {
            Divider()
        }
    }
}

struct OutlineList: View {
    @ObservedObject var buffer: BufferDocument
    @EnvironmentObject private var state: AppState

    var body: some View {
        if buffer.outline.isEmpty {
            Text("No symbols")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(10)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(buffer.outline) { row in
                        HStack(spacing: 6) {
                            Text(row.kindLabel)
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .leading)
                            Text(row.name)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.jumpTo(byte: row.startByte)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}
