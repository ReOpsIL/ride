import Foundation

enum LaunchArguments {
    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    static func value(after flag: String) -> String? {
        value(after: flag, in: ProcessInfo.processInfo.arguments)
    }
}
