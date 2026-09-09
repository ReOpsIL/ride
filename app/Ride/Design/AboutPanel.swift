import AppKit

enum AboutPanel {
    static let engineVersion = "0.1.0"

    static func show() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? engineVersion
        let build = info["CFBundleVersion"] as? String ?? "1"
        let credits = NSAttributedString(
            string: "Engine \(engineVersion) · tree-sitter · Tantivy\nNative Rust editor for macOS",
            attributes: [
                .font: Tokens.nsUI(11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage as Any,
            .applicationName: "Ride",
            .applicationVersion: version,
            .version: build,
            .credits: credits,
        ])
    }
}
