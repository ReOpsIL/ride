import AppKit
import SwiftUI

struct CopyCommandButton: View {
    let command: String
    @State private var copied = false

    var body: some View {
        Button(copied ? "Copied" : "Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            copied = true
        }
        .controlSize(.small)
        .font(Tokens.ui(11))
    }
}
