import SwiftUI

struct ViewCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Toggle("Project Sidebar", isOn: Binding(get: { menu.showSidebar }, set: { _ in state.showSidebar.toggle() }))
                .keyboardShortcut("1", modifiers: .command)
            Toggle("Outline", isOn: Binding(get: { menu.outlinePanel }, set: { _ in state.toggleOutlinePanel() }))
                .keyboardShortcut("7", modifiers: .command)
            Toggle("Problems", isOn: Binding(get: { menu.showProblems }, set: { _ in state.toggleProblems() }))
                .keyboardShortcut("6", modifiers: .command)
            Button("Toggle Markdown Preview") { state.togglePreview() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(!menu.previewAvailable)
            Divider()
            Button("Zoom In") { state.zoom(1) }
                .keyboardShortcut("=", modifiers: .command)
            Button("Zoom Out") { state.zoom(-1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { state.resetZoom() }
                .keyboardShortcut("0", modifiers: [.command, .control])
            Divider()
            Toggle("Soft Wrap", isOn: Binding(get: { menu.softWrap }, set: { _ in state.toggleSoftWrap() }))
            Toggle("Show Whitespace", isOn: Binding(get: { menu.visibleWhitespace }, set: { _ in state.toggleWhitespace() }))
            Toggle("Indent Guides", isOn: Binding(get: { menu.indentGuides }, set: { _ in state.toggleIndentGuides() }))
            Divider()
            Button("Open in Split") { state.openInSplit() }
                .disabled(!menu.hasEditor)
            Button("Toggle Split") { state.toggleSplit() }
                .keyboardShortcut("\\", modifiers: .command)
                .disabled(!menu.hasEditor)
            Button("Close Split") { state.closeSplit() }
                .disabled(!menu.hasSplit)
        }
    }
}
