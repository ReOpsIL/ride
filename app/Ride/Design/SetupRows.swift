import Foundation

struct SetupTool: Equatable {
    let name: String
    let installed: Bool
    let command: String?
    let manual: Bool
}

struct SetupRow: Identifiable, Equatable {
    let name: String
    let title: String
    let purpose: String
    let installed: Bool
    let command: String?
    let manual: Bool

    var id: String { name }
}

enum SetupRows {
    static let debuggingName = "debugging"
    static let debuggingCommand = "sudo DevToolsSecurity -enable"

    static let names = ["command-line-tools", "rustup", "rust-src", "cmake"]

    static func title(of name: String) -> String {
        switch name {
        case "command-line-tools": "Command Line Tools"
        case "rust-src": "Standard library sources"
        case "cmake": "CMake"
        case debuggingName: "Debugging"
        default: name
        }
    }

    static func purpose(of name: String) -> String {
        switch name {
        case "command-line-tools": "clang, headers and git"
        case "rustup": "Rust toolchains and components"
        case "rust-src": "completion and docs from std"
        case "cmake": "configure and build C and C++ projects"
        case debuggingName: "lets Ride attach the debugger without a password prompt"
        default: ""
        }
    }

    static func rows(tools: [SetupTool], developerMode: Bool) -> [SetupRow] {
        let byName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return names.compactMap { name in byName[name].map(row(from:)) } + [debugging(developerMode)]
    }

    static func allGreen(_ rows: [SetupRow]) -> Bool {
        rows.allSatisfy(\.installed)
    }

    private static func row(from tool: SetupTool) -> SetupRow {
        SetupRow(
            name: tool.name,
            title: title(of: tool.name),
            purpose: purpose(of: tool.name),
            installed: tool.installed,
            command: tool.command,
            manual: tool.manual
        )
    }

    private static func debugging(_ enabled: Bool) -> SetupRow {
        SetupRow(
            name: debuggingName,
            title: title(of: debuggingName),
            purpose: purpose(of: debuggingName),
            installed: enabled,
            command: debuggingCommand,
            manual: true
        )
    }
}
