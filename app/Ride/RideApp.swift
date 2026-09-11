import AppKit
import SwiftUI

@main
struct RideApp: App {
    @NSApplicationDelegateAdaptor(RideAppDelegate.self) private var appDelegate
    private let state: AppState
    private let updater: UpdateController
    @ObservedObject private var menu: MenuModel

    init() {
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
        UserDefaults.standard.set(true, forKey: "ApplePersistenceIgnoreState")
        NSWindow.allowsAutomaticWindowTabbing = false
        let state = AppState()
        self.state = state
        self.updater = UpdateController()
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
            if updater.isConfigured {
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates…") { updater.checkForUpdates() }
                }
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

final class RideAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ app: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ app: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }
}
