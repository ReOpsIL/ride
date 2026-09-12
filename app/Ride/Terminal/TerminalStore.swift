import AppKit
import Combine
import Foundation

final class TerminalStore: ObservableObject {
    @Published private(set) var tabs = TerminalTabs()
    var font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    var colors = TerminalColors.from(ThemeStore.shared.theme)
    private var sessions: [UUID: TerminalSession] = [:]
    private var workspaceSink: AnyCancellable?

    @discardableResult
    func open(directory: String?) -> UUID {
        let item = TerminalTabItem(title: TerminalTabs.title(for: directory), directory: directory)
        let session = TerminalSession(id: item.id, directory: directory, font: font, colors: colors)
        session.onTitle = { [weak self] id, title in
            self?.tabs.rename(id, title: title)
        }
        session.onExit = { [weak self] id in
            DispatchQueue.main.async { self?.close(id) }
        }
        sessions[item.id] = session
        tabs.add(item)
        return item.id
    }

    func session(_ id: UUID) -> TerminalSession? {
        sessions[id]
    }

    func select(_ id: UUID) {
        tabs.select(id)
    }

    func close(_ id: UUID) {
        sessions[id]?.terminate()
        sessions.removeValue(forKey: id)
        tabs.close(id)
    }

    func closeAll() {
        for session in sessions.values {
            session.terminate()
        }
        sessions = [:]
        tabs.removeAll()
    }

    func focusSelected() {
        guard let id = tabs.selected else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.sessions[id]?.focus()
        }
    }

    func applyTheme(font: NSFont, colors: TerminalColors) {
        self.font = font
        self.colors = colors
        for session in sessions.values {
            session.apply(font: font, colors: colors)
        }
    }

    func observeWorkspace(_ publisher: Published<URL?>.Publisher) {
        workspaceSink = publisher.dropFirst().sink { [weak self] _ in
            self?.closeAll()
        }
    }
}
