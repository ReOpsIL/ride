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
                }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
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
                Button("Show Problems") {
                    state.toggleProblems()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
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
