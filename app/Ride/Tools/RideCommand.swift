import Foundation

enum RideCommandState: Equatable {
    case installed
    case missing
    case failed(String)
}

final class RideCommand: ObservableObject {
    static let shared = RideCommand()
    static let linkPath = "/usr/local/bin/ride"

    @Published private(set) var state: RideCommandState = .missing
    @Published private(set) var busy = false

    static var helperURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ride")
    }

    static var isInstalled: Bool {
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: linkPath) else {
            return false
        }
        return URL(fileURLWithPath: target).standardizedFileURL == helperURL.standardizedFileURL
    }

    func refresh() {
        state = Self.isInstalled ? .installed : .missing
    }

    func install() {
        guard !busy else {
            return
        }
        busy = true
        let script = Self.appleScript(Self.linkCommand)
        DispatchQueue.global(qos: .userInitiated).async {
            let (output, success) = ProcessRun.capture("/usr/bin/osascript", ["-e", script])
            DispatchQueue.main.async { [weak self] in
                self?.busy = false
                self?.state = success && Self.isInstalled ? .installed : .failed(output)
            }
        }
    }

    private static var linkCommand: String {
        let link = ProcessRun.shellQuoted(linkPath)
        return "mkdir -p /usr/local/bin && ln -sf \(ProcessRun.shellQuoted(helperURL.path)) \(link)"
    }

    private static func appleScript(_ command: String) -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }
}
