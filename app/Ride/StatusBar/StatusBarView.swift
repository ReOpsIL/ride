import AppKit
import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            if let branch = state.git.branch {
                StatusSegment(icon: "arrow.triangle.branch", text: branch, help: "Git branch")
            }
            StatusSegment(text: "Ln \(state.cursorLine), Col \(state.cursorColumn)", help: "Cursor position")
            StatusSegment(icon: pathIcon, text: state.relativePath, help: state.activeBuffer?.fileURL?.path ?? state.relativePath)
            if let error = state.formatError {
                StatusSegment(icon: "exclamationmark.circle", text: "\(formatter): \(error)", tint: ts.ui.error, help: error)
            }
            Spacer(minLength: 0)
            AIStatusView()
            CheckStatusView()
            IndexStatusView()
            if let buffer = state.activeBuffer {
                StatusSegment(text: buffer.lineEnding, help: "Line endings") {
                    LineEndingMenu.present(buffer: buffer, state: state)
                }
            }
            StatusSegment(text: "Spaces: \(state.prefs.tabWidth)", help: "Indentation")
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: Tokens.Size.statusBar)
        .frame(maxWidth: .infinity)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .top) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }

    private var pathIcon: String {
        guard let buffer = state.activeBuffer else {
            return "doc"
        }
        return FileIcon.spec(for: buffer, chrome: ts.chrome).symbol
    }

    private var formatter: String {
        guard let buffer = state.activeBuffer, let engine = RideEngineClient.shared.engine else {
            return "format"
        }
        let name = engine.formatterName(path: buffer.fileURL?.path, text: buffer.text)
        return name.isEmpty ? "format" : name
    }
}

final class LineEndingMenu: NSObject {
    static let shared = LineEndingMenu()
    private weak var buffer: BufferDocument?
    private weak var state: AppState?

    static func present(buffer: BufferDocument, state: AppState) {
        shared.buffer = buffer
        shared.state = state
        let menu = NSMenu()
        let keep = menu.addItem(withTitle: "Keep", action: #selector(keepEndings), keyEquivalent: "")
        keep.target = shared
        let convert = menu.addItem(withTitle: "Convert to LF", action: #selector(convertToLF), keyEquivalent: "")
        convert.target = shared
        if let event = NSApp.currentEvent, let view = event.window?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    @objc private func keepEndings() {
        state?.updatePrefs { $0.lineEndings = LineEndings.keep }
    }

    @objc private func convertToLF() {
        buffer?.convertToLF()
        state?.updatePrefs { $0.lineEndings = LineEndings.lf }
    }
}
