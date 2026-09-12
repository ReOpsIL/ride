import Foundation

struct WatchRow: Identifiable, Equatable {
    let id: String
    var value: String
    var typeName: String?
    var failed: Bool

    var expression: String {
        id
    }
}

final class DebugPanelModel: ObservableObject {
    static let shared = DebugPanelModel()
    static let queue = DispatchQueue(label: "ride.debug.load", qos: .utility, attributes: .concurrent)

    @Published var visible = false
    @Published var showEvaluate = false
    @Published private(set) var threads: [DebugThread] = []
    @Published private(set) var frames: [StackFrame] = []
    @Published private(set) var selectedThread: Int64?
    @Published private(set) var selectedFrame: Int64?
    @Published private(set) var tree = VariableTree()
    @Published private(set) var watches: [WatchRow] = []

    var onFrame: ((String, UInt32) -> Void)?
    var onWatchesChanged: (() -> Void)?
    private var loads = DebugLoadState()
    private var seenSequence = 0

    var expressions: [String] {
        watches.map(\.expression)
    }

    var isStopped: Bool {
        DebugController.shared.isStopped
    }

    var stopGeneration: Int {
        loads.generation
    }

    func beginLoad(_ key: String) -> Int? {
        loads.begin(key)
    }

    func finishLoad(_ key: String, generation: Int) -> Bool {
        loads.finish(key, generation: generation)
    }

    func isCurrent(_ generation: Int) -> Bool {
        loads.isCurrent(generation)
    }

    func restore(watches list: [String]) {
        watches = list.map { WatchRow(id: $0, value: "", typeName: nil, failed: false) }
        refreshWatches()
    }

    func addWatch(_ text: String) {
        let expression = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty, !watches.contains(where: { $0.id == expression }) else {
            return
        }
        watches.append(WatchRow(id: expression, value: "", typeName: nil, failed: false))
        refreshWatches()
        onWatchesChanged?()
    }

    func removeWatch(id: String) {
        watches.removeAll { $0.id == id }
        onWatchesChanged?()
    }

    func apply(watches rows: [WatchRow]) {
        watches = watches.map { row in
            rows.first { $0.id == row.id } ?? row
        }
    }

    func sessionChanged() {
        let sequence = DebugController.shared.stopSequence
        guard sequence != seenSequence else {
            return
        }
        seenSequence = sequence
        loads.invalidate()
        guard DebugController.shared.isStopped else {
            frames = []
            selectedFrame = nil
            tree.clear()
            clearWatchValues()
            if !DebugController.shared.isActive {
                threads = []
                selectedThread = nil
            }
            return
        }
        reloadThreads()
    }

    func selectThread(_ id: Int64) {
        selectedThread = id
        reloadFrames(thread: id)
    }

    func selectFrame(_ id: Int64, jump: Bool = true) {
        selectedFrame = id
        tree.clear()
        loadScopes(frame: id)
        refreshWatches()
        guard jump, let frame = frames.first(where: { $0.id == id }), let path = frame.path else {
            return
        }
        onFrame?(path, frame.line)
    }

    func toggle(_ row: VariableRow) {
        guard row.node.isExpandable else {
            return
        }
        let open = tree.toggle(row.node.id)
        guard open, !tree.isLoaded(row.node.id) else {
            return
        }
        loadChildren(of: row.node)
    }

    func loadMore(_ node: VariableNode) {
        loadChildren(of: node)
    }

    func apply(threads list: [DebugThread]) {
        threads = list
        guard let wanted = DebugController.shared.stoppedThread ?? list.first?.id else {
            return
        }
        selectThread(wanted)
    }

    func apply(frames list: [StackFrame]) {
        frames = list
        guard let first = list.first else {
            selectedFrame = nil
            return
        }
        selectFrame(first.id, jump: false)
    }

    func apply(children nodes: [VariableNode], of node: VariableNode) {
        tree.append(nodes, to: node.id, expected: node.childrenCount)
    }

    func expand(_ node: VariableNode) {
        tree.toggle(node.id)
    }

    func apply(roots nodes: [VariableNode]) {
        tree.replace(nodes, of: VariableTree.rootId)
    }

    private func clearWatchValues() {
        watches = watches.map { row in
            WatchRow(id: row.id, value: "", typeName: nil, failed: false)
        }
    }
}
