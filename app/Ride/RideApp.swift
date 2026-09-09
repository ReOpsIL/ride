import AppKit
import SwiftUI

@main
struct RideApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(state.isLightTheme ? .light : .dark)
                .onAppear {
                    NSApp.appearance = NSAppearance(named: state.isLightTheme ? .aqua : .darkAqua)
                    DemoLaunch.start(state: state)
                }
        }
        .defaultSize(width: 1200, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Ride") {
                    AboutPanel.show()
                }
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    ShortcutsPanel.show()
                }
                .keyboardShortcut("/", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    state.newUntitled()
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("Open Folder…") {
                    state.openFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
                if !state.recent.isEmpty {
                    Menu("Open Recent") {
                        ForEach(state.recent, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                state.open(url)
                            }
                        }
                    }
                }
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    state.saveActive()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Close Editor") {
                    if let id = state.activeID {
                        state.closeBuffer(id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                Button("Reindex") {
                    state.reindex()
                }
            }
            CommandGroup(after: .pasteboard) {
                Button("Format Document") {
                    state.formatActive()
                }
                .keyboardShortcut("i", modifiers: [.control, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    state.showSidebar.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                Button("Show Problems") {
                    state.toggleProblems()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Toggle Markdown Preview") {
                    state.togglePreview()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(!state.previewAvailable)
            }
            CommandMenu("Build") {
                Button("Check") {
                    state.runCheck()
                }
                .keyboardShortcut("b", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Open Quickly…") {
                    state.toggleQuickOpen()
                }
                .keyboardShortcut("p", modifiers: .command)
                Button("Find…") {
                    state.toggleFind()
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") {
                    state.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") {
                    state.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Go to Symbol in File…") {
                    state.toggleSymbolInFile()
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("Go to Symbol in Project…") {
                    state.toggleSymbolPicker()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Find in Project…") {
                    state.toggleProjectFind()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Go to Definition") {
                    state.goToDefinition()
                }
                .keyboardShortcut(FunctionKeys.f12, modifiers: [])
            }
        }
        Settings {
            PreferencesView()
                .environmentObject(state)
        }
    }
}
