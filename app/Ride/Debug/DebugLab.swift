import Foundation

struct DebugLab {
    static let target = "debugger-lab"
    static let workers = 3

    let language: BufferLanguage
    let fileExtension: String

    static func detect(_ root: URL?) -> DebugLab? {
        guard let root else {
            return nil
        }
        let labs = [DebugLab(language: .rust, fileExtension: "rs"), DebugLab(language: .cpp, fileExtension: "cpp"), DebugLab(language: .c, fileExtension: "c")]
        return labs.first { lab in
            ["stepping", "threads"].allSatisfy { FileManager.default.fileExists(atPath: root.appendingPathComponent(lab.file($0)).path) }
        }
    }

    func file(_ scenario: String) -> String {
        "src/\(scenario).\(fileExtension)"
    }

    var steppedInto: String {
        language == .rust ? "double" : "twice"
    }

    var stackFrames: [String] {
        ["discount", "price", "checkout", scenarioFrame("stack")]
    }

    func scenarioFrame(_ scenario: String) -> String {
        switch language {
        case .rust:
            return "\(scenario)::run"
        case .cpp:
            return "lab::\(scenario)"
        default:
            return "lab_\(scenario)"
        }
    }

    var workerNames: [String] {
        language == .rust ? (0..<Self.workers).map { "worker-\($0)" } : []
    }
}
