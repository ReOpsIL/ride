import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TabStrip: View {
    let pane: Pane
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(pane.tabs.compactMap(state.buffer)) { buffer in
                    TabItem(buffer: buffer, selected: buffer.id == pane.activeID, paneID: pane.id)
                        .onDrag { TabPasteboard.provider(buffer.id) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: Tokens.Size.tab)
        .frame(maxWidth: .infinity)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .trailing) {
            LinearGradient(colors: [ts.ui.bgRaised.opacity(0), ts.ui.bgRaised], startPoint: .leading, endPoint: .trailing)
                .frame(width: 20)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
        .overlay(alignment: .top) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
        .contentShape(Rectangle())
        .onDrop(of: [.utf8PlainText, .plainText], isTargeted: nil) { providers in
            TabPasteboard.take(providers) { id in
                state.moveTab(id, to: pane.id)
            }
        }
    }
}

enum TabPasteboard {
    static func provider(_ id: UUID) -> NSItemProvider {
        NSItemProvider(object: id.uuidString as NSString)
    }

    static func take(_ providers: [NSItemProvider], done: @escaping (UUID) -> Void) -> Bool {
        guard let provider = providers.first else {
            return false
        }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String, let id = UUID(uuidString: string) else {
                return
            }
            DispatchQueue.main.async {
                done(id)
            }
        }
        return true
    }
}
