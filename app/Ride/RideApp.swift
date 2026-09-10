import AppKit
import SwiftUI

@main
struct RideApp: App {
    private let state: AppState
    @ObservedObject private var menu: MenuModel

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
        let state = AppState()
        self.state = state
        _menu = ObservedObject(wrappedValue: state.menu)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
        }
        .defaultSize(width: 1200, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Ride") { AboutPanel.show() }
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { ShortcutsPanel.show() }
                    .keyboardShortcut("?", modifiers: .command)
            }
            FileCommands(state: state, menu: menu)
            EditCommands(state: state, menu: menu)
            ViewCommands(state: state, menu: menu)
            NavigateCommands(state: state, menu: menu)
            CodeCommands(state: state, menu: menu)
        }
        Settings {
            PreferencesView()
                .environmentObject(state)
        }
    }
}
