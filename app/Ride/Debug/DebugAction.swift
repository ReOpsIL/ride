import SwiftUI

struct DebugGates: Equatable {
    var canDebug = false
    var isActive = false
    var isStopped = false
    var isRunning = false
}

enum DebugAction: CaseIterable, Identifiable {
    case start
    case resume
    case stepOver
    case stepInto
    case stepOut
    case pause
    case stop

    static let groups: [[DebugAction]] = [[.start, .resume], [.stepOver, .stepInto, .stepOut], [.pause, .stop]]

    var id: Self { self }

    var title: String {
        switch self {
        case .start: return "Debug"
        case .resume: return "Continue"
        case .stepOver: return "Step Over"
        case .stepInto: return "Step Into"
        case .stepOut: return "Step Out"
        case .pause: return "Pause"
        case .stop: return "Stop"
        }
    }

    var symbol: String {
        switch self {
        case .start: return "ladybug"
        case .resume: return "play.fill"
        case .stepOver: return "arrowshape.turn.up.right"
        case .stepInto: return "arrow.down.to.line"
        case .stepOut: return "arrow.up.to.line"
        case .pause: return "pause.fill"
        case .stop: return "stop.fill"
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .start: return KeyboardShortcut("r", modifiers: [.control, .command])
        case .resume: return KeyboardShortcut("r", modifiers: [.command, .option])
        case .stepOver: return KeyboardShortcut(FunctionKeys.f8, modifiers: [])
        case .stepInto: return KeyboardShortcut(FunctionKeys.f7, modifiers: [])
        case .stepOut: return KeyboardShortcut(FunctionKeys.f8, modifiers: .shift)
        case .pause: return nil
        case .stop: return KeyboardShortcut(FunctionKeys.f2, modifiers: .command)
        }
    }

    var shortcutLabel: String? {
        switch self {
        case .start: return "⌃⌘R"
        case .resume: return "⌥⌘R"
        case .stepOver: return "F8"
        case .stepInto: return "F7"
        case .stepOut: return "⇧F8"
        case .pause: return nil
        case .stop: return "⌘F2"
        }
    }

    var help: String {
        shortcutLabel.map { "\(title) (\($0))" } ?? title
    }

    func isEnabled(_ gates: DebugGates) -> Bool {
        switch self {
        case .start: return gates.canDebug && !gates.isActive
        case .resume, .stepOver, .stepInto, .stepOut: return gates.isStopped
        case .pause: return gates.isRunning
        case .stop: return gates.isActive
        }
    }

    func perform(_ state: AppState) {
        switch self {
        case .start: state.startDebug()
        case .resume: state.debugCommand(.continue)
        case .stepOver: state.debugCommand(.next)
        case .stepInto: state.debugCommand(.stepIn)
        case .stepOut: state.debugCommand(.stepOut)
        case .pause: state.debugCommand(.pause)
        case .stop: state.stopDebug()
        }
    }
}
