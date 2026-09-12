import SwiftUI

struct DebugFramesList: View {
    @ObservedObject var model: DebugPanelModel
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: threadBinding) {
                ForEach(model.threads, id: \.id) { thread in
                    Text("\(thread.name) · \(thread.id)").tag(thread.id)
                }
            }
            .labelsHidden()
            .font(Tokens.ui(11))
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xs)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.frames, id: \.id) { frame in
                        DebugFrameRow(frame: frame, selected: model.selectedFrame == frame.id) {
                            model.selectFrame(frame.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var threadBinding: Binding<Int64> {
        Binding(
            get: { model.selectedThread ?? model.threads.first?.id ?? 0 },
            set: { model.selectThread($0) }
        )
    }
}

struct DebugFrameRow: View {
    let frame: StackFrame
    let selected: Bool
    let action: () -> Void
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s) {
                Text(frame.name)
                    .font(Tokens.mono(11))
                    .foregroundStyle(ts.ui.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(location)
                    .font(Tokens.mono(10))
                    .foregroundStyle(ts.ui.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? ts.ui.bgSelection : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var location: String {
        guard let path = frame.path else {
            return ""
        }
        return "\(URL(fileURLWithPath: path).lastPathComponent):\(frame.line)"
    }
}

struct DebugVariablesList: View {
    @ObservedObject var model: DebugPanelModel
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.tree.rows) { row in
                    DebugVariableRow(row: row) {
                        model.toggle(row)
                    }
                    if model.tree.isExpanded(row.node.id), model.tree.hasMore(row.node.id) {
                        Button("more…") {
                            model.loadMore(row.node)
                        }
                        .buttonStyle(.plain)
                        .font(Tokens.ui(10))
                        .foregroundStyle(ts.ui.accent)
                        .padding(.leading, CGFloat(row.depth + 1) * 12 + Tokens.Space.m)
                    }
                }
            }
            .padding(.vertical, Tokens.Space.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DebugVariableRow: View {
    let row: VariableRow
    let toggle: () -> Void
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: row.expanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(width: 10)
                .opacity(row.node.isExpandable ? 1 : 0)
            Text(row.node.name)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textPrimary)
            Text(row.node.value)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let type = row.node.typeName {
                Text(type)
                    .font(Tokens.mono(10))
                    .foregroundStyle(ts.ui.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, CGFloat(row.depth) * 12 + Tokens.Space.m)
        .padding(.trailing, Tokens.Space.m)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
    }
}
